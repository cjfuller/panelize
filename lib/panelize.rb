#--
# Copyright (c) 2013 Colin J. Fuller
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++

require "panelize/version"
require 'rimageanalysistools'
require 'rimageanalysistools/get_image'
require 'rimageanalysistools/image_shortcuts'
require 'trollop'
require 'highline/import'

module Panelize

  java_import Java::edu.stanford.cfuller.imageanalysistools.image.ImageCoordinate
  java_import Java::edu.stanford.cfuller.imageanalysistools.image.ImageFactory
  java_import Java::edu.stanford.cfuller.imageanalysistools.image.Histogram
  java_import Java::ij.process.ColorProcessor
  java_import Java::ij.ImagePlus
  java_import Java::ij.io.FileSaver

  class << self

    def box_channel(im, ch)
      lower = ImageCoordinate[0,0,0,0,0]
      upper = ImageCoordinate.cloneCoord(im.getDimensionSizes)
      lower[:c] = ch
      upper[:c] = ch+1
      im.setBoxOfInterest(lower, upper)
      lower.recycle
      upper.recycle
      nil
    end

    def display(im, params)
      box_channel(im, params[:col_chs][0])
      max = Histogram.findMaxVal(im)
      im.clearBoxOfInterest
      imp = im.toImagePlus
      imp.setOpenAsHyperStack true
      imp.updatePosition(params[:col_chs][0]+1, 1, 1)
      imp.setDisplayRange(0, max)
      imp.setRoi 0,0, params[:size], params[:size]
      imp.show
      ask("Move the region of interest to where you want to crop and press enter when done.")
      ul = [imp.getRoi.getPolygon.xpoints[0], imp.getRoi.getPolygon.ypoints[0]]
    end

    def crop(im, ul, params)
      sizes = ImageCoordinate.cloneCoord(im.getDimensionSizes)
      sizes[:x] = params[:size]
      sizes[:y] = params[:size]
      ul_coord = ImageCoordinate[ul[0], ul[1], 0,0,0]
      im_crop = im.subImage(sizes, ul_coord)
      im.toImagePlus.close
      sizes.recycle
      ul_coord.recycle
      im_crop
    end

    def load_and_crop(fn, params)
      im = RImageAnalysisTools.get_image(fn)
      ul = display(im, params)
      crop(im, ul, params)
    end

    def calculate_channel_scale(ims, params)
      scale = {}

      params[:col_chs].each do |ch|
        min = Float::MAX
        max = -1.0*Float::MAX

        ims.each do |im|
          box_channel(im, ch)

          h = Histogram.new(im)
          min = h.getMinValue if h.getMinValue < min
          max = h.getMaxValue if h.getMaxValue > max
        end

        scale[ch] = [min + params[:scaleundersat]/100*(max-min), max - params[:scalesat]/100*(max-min)]
      end

      scale
    end

    def scale_to_8_bit(value, scale)
      value = 255*(value - scale[0])/(scale[1]-scale[0])
      value = 0 if value < 0
      value = 255 if value > 255
      value
    end

    def add_scalebar(panel_image, params)
      scalebar_length_px = params[:scalebar]/params[:mpp]

      y_start = calculate_height(params) - 2*params[:spacing]
      x_start = params[:spacing]

      x_start.upto(x_start + scalebar_length_px - 1) do |x|
        y_start.upto(y_start + params[:spacing] - 1) do |y|
          panel_image.putPixel(x, y, [255, 255, 255].to_java(:int))
        end
      end
    end


    def place_panel(panel_image, start_coord, image, channel, rgb_chs, scales)
      box_channel(image, channel)

      rgb_mult = [0, 0, 0]
      rgb_mult[0] = 1 if rgb_chs.include? :r
      rgb_mult[1] = 1 if rgb_chs.include? :g
      rgb_mult[2] = 1 if rgb_chs.include? :b

      image.each do |ic|
        v = scale_to_8_bit(image[ic], scales[ic[:c]])
        curr_val = panel_image.getPixel(ic[:x] + start_coord[:x], ic[:y] + start_coord[:y], nil)
        panel_image.putPixel(ic[:x] + start_coord[:x], ic[:y] + start_coord[:y], rgb_mult.map.with_index { |e, i| e*v + (1-e)*curr_val[i]}.to_java(:int))
      end

      nil
    end

    def calculate_width(params)
      (params[:col_chs].size + 1)*params[:size] + params[:col_chs].size*params[:spacing]
    end

    def calculate_height(params)
      (params[:n_rows])*params[:size] + (params[:n_rows]-1)*params[:spacing]
    end

    def calculate_row_pos(n, params)
      n*params[:size] + n*params[:spacing]
    end

    def calculate_col_pos(n, params)
      n*params[:size] + n*params[:spacing]
    end

    def initialize_panel(params)
      w = calculate_width(params)
      h = calculate_height(params)

      im = ColorProcessor.new(w, h)
      w.times do |x|
        h.times do |y|
          im.putPixel(x, y, [255, 255, 255].to_java(:int))
        end
      end

      im
    end


    def make_panels(ims, scale, params)
      panels = initialize_panel(params)

      params[:n_rows].times do |row|
        params[:col_chs].size.times do |col|
          place_panel(panels, {y: calculate_row_pos(row, params), x: calculate_col_pos(col, params)}, ims[row], params[:col_chs][col], [:r, :g, :b], scale)
        end

        zero_im = ImageFactory.createWritable(ims[0])
        zero_im.each { |ic| zero_im[ic] = 0.0 }

        #zero out merge first in case not all channels are being used
        [:r, :g, :b].each do |ch, i|
          next if params[:col_chs].include? ch
          place_panel(panels, {y:calculate_row_pos(row, params), x: calculate_col_pos(params[:col_chs].size, params)}, zero_im, params[:col_chs][0], [ch], scale)
        end
        
        params[:col_order].each_with_index do |ch, i|
          if params[:col_chs].size > i then
            place_panel(panels, {y:calculate_row_pos(row, params), x: calculate_col_pos(params[:col_chs].size, params)}, ims[row], params[:col_chs][i], [ch], scale)
          else 
            place_panel(panels, {y:calculate_row_pos(row, params), x: calculate_col_pos(params[:col_chs].size, params)}, zero_im, params[:col_chs][0], [ch], scale)
          end
        end
      end

      panels
    end

    def save_image(panels)
      fs = FileSaver.new(ImagePlus.new("panels", panels))
      fn = "panels_#{Time.now.to_i}.tif"
      fs.saveAsTiff(fn)
      puts "Panels saved as #{fn}"
    end

    def ask_for_params(params)
      params[:n_rows] = ask("Enter the number of treatments (rows) to panelize: ", Integer)
      params[:col_chs] = ask("Enter the channel numbers to display (comma-separated): ", lambda { |str| str.split(/,\s*/).map(&:to_i) })
      params[:col_order] = ask ("Enter the channel order (comma-separated) (default r,g,b if no order given): "), lambda { |str| str.empty? ? [:r, :g, :b] : str.split(/,\s*/).map(&:to_sym) }
      params[:fns] = []
      params[:n_rows].times do |i|
        params[:fns] << ask("Enter the filename for treatment #{i+1}: ").gsub("'", "") #remove quotes if drag and drop fn insertion in the terminal puts them in
      end
      params[:mpp] = ask("Enter the number of microns per pixel (for calculating the length of a scalebar): ", Float)

    end

    def go
      params = Trollop::options do 
        opt :spacing, "Spacing between image panels in pixels", type: :integer, default: 5
        opt :size, "Size of the image in pixels", type: :integer, default: 256
        opt :scalebar, "Size of the scalebar in microns", type: :float, default: 5.0
        opt :scalesat, "Amount in percent by which to saturate images", type: :float, default: 15.0
        opt :scaleundersat, "Amount in percent by which to undersaturate images", type: :float, default: 5.0
      end

      ask_for_params(params)

      ims = []
      params[:fns].each do |fn|
        ims << load_and_crop(fn, params)
      end

      scale = calculate_channel_scale(ims, params)
      panels = make_panels(ims, scale, params)
      add_scalebar(panels, params)
      save_image(panels)
    end
  end
end

