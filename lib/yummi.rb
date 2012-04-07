#                         The MIT License
#
# Copyright (c) 2012 Marcelo Guimarães <ataxexe@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative "yummi/version"
require_relative "yummi/table"
require_relative "yummi/logger"

module Yummi

  module Color
    # Colors from default linux terminal scheme
    COLORS = {
      :nothing => '0;0',

      :black => '0;30',
      :red => '0;31',
      :green => '0;32',
      :brown => '0;33',
      :blue => '0;34',
      :purple => '0;35',
      :cyan => '0;36',
      :gray => '0;37',

      :black_underscored => '4;30',
      :red_underscored => '4;31',
      :green_underscored => '4;32',
      :brown_underscored => '4;33',
      :blue_underscored => '4;34',
      :purple_underscored => '4;35',
      :cyan_underscored => '4;36',
      :gray_underscored => '4;37',

      :blink_black => '5;30',
      :blink_red => '5;31',
      :blink_green => '5;32',
      :blink_brown => '5;33',
      :blink_blue => '5;34',
      :blink_purple => '5;35',
      :blink_cyan => '5;36',
      :blink_gray => '5;37',

      :highlight_black => '5;30',
      :highlight_red => '5;31',
      :highlight_green => '5;32',
      :highlight_brown => '5;33',
      :highlight_blue => '5;34',
      :highlight_purple => '5;35',
      :highlight_cyan => '5;36',
      :highlight_gray => '5;37',

      :intense_gray => '1;30',
      :intense_red => '1;31',
      :intense_green => '1;32',
      :intense_yellow => '1;33',
      :yellow => '1;33',
      :intense_blue => '1;34',
      :intense_purple => '1;35',
      :intense_cyan => '1;36',
      :intense_white => '1;37',
      :white => '1;37'
    }
    # Types of color
    TYPES = {
      :normal => 0,
      :intense => 1,
      :underscored => 4,
      :blink => 5,
      :highlight => 7
    }
    # Parses the key
    def self.parse(key)
      keys = key.to_s.split '_'
      type = keys[0].to_sym
      color = keys[1].to_i
      "#{TYPES[type]};3#{color - 1}"
    end
    # Escape the given text with the given color code
    def self.escape(key)
      return key unless key
      color = COLORS[key]
      color ||= parse(key)
      "\033[#{color}m"
    end
    # Colorize the given text with the given color
    def self.colorize(str, color)
      col, nocol = [color, :nothing].map { |key| Color.escape(key) }
      col ? "#{col}#{str}#{nocol}" : str
    end

  end

  module Aligner

    def self.right text, width
      text.rjust(width)
    end

    def self.left text, width
      text.ljust(width)
    end

  end

  module IndexedDataColorizer

    def self.if first, operation, second, params
      lambda do |row|
        params[:with] if row[first].send operation, row[second]
      end
    end

    def self.unless first, operation, second, params
      lambda do |row|
        params[:with] unless row[first].send operation, row[second]
      end
    end

    def self.case *args
      lambda do |value|
        color = nil
        args.each do |arg|
          _color = self.if(*arg).call(value)
          color = _color if _color
        end
        color
      end
    end

  end

  module Colorizer

    def self.if operation, argument, params
      lambda do |value|
        params[:with] if value.send operation, argument
      end
    end

    def self.unless operation, argument, params
      lambda do |value|
        params[:with] unless value.send operation, argument
      end
    end

    def self.case *args
      lambda do |value|
        color = nil
        args.each do |arg|
          _color = self.if(*arg).call(value)
          color = _color if _color
        end
        color
      end
    end

  end

  module Formatter

    def self.yes_or_no
      lambda do |value|
        value ? "Yes" : "No"
      end
    end

  end

  class IndexedData

    def initialize aliases, data
      @aliases = aliases
      @data = data
    end

    def [] value
      if value.is_a? Fixnum
        @data[value]
      else
        @data[@aliases.index(value)]
      end
    end

  end


end

require_relative 'yummi/no_colors' if RUBY_PLATFORM['mingw'] #Windows
