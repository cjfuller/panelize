# Panelize

Panelize is a script for arranging microscopy images into a grid with constant leveling for making figures.  Multiple channels are supported with up to three-channel RGB merge.  An arbitrary number of treatments is supported; each channel is scaled the same across all treatments.  Adds a scalebar to the lower left image in the grid.

## Installation

Panelize requires jruby as it uses java libraries.

Execute:

    $ gem install panelize

Or for an application using bundler, add this line to your application's Gemfile:

    gem 'panelize'

And then execute:

    $ bundle


## Usage

Run `panelize` from the command prompt and answer the prompts it prints out (which will ask for input images, etc.).

When asked for the channels to display, these should be provided as numbers (with the first channel having index 0) where each number refers to the order the channels are stored in the image file.  The order in which you list the channels will be the order they are displayed in the grid from left to right, and these will appear in the merge as red, green, and blue in that order.  More than three channels can be displayed, but only the first three will appear in the merge.

Additional options are available at the command line; run `panelize --help` for a description.

Panelizer expects that the input images will be multi-channel images in a format that the [bio-formats library](http://www.openmicroscopy.org/site/products/bio-formats) can read and recognize as having multiple channels.  If the images have multiple axial or time planes, only the final one will be used for display.

The final set of panels will be saved with a unique filename (which will be printed out) to the directory from which you ran the script.

If you want to tweak the scaling of the images, you should adjust the command line parameters scalesat and scaleundersat (run `panelize --help` to see the syntax for using these).  If both these parameters are set to zero, in each channel, the images will be scaled between the min and max value appearing in that channel in any of the images.  Setting these to a larger value will narrow the display range by the value supplied (in percent) from either the upper end (the scalesat parameter) or the lower end (scaleundersat), making the image appear brighter or the background dimmer, respectively.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Panelize is distributed under the MIT/X11 license (see LICENSE.txt for the full license).
