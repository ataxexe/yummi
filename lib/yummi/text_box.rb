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

module Yummi

  # A box to decorate texts
  class TextBox
    # The border color
    attr_accessor :color
    # The box content
    attr_accessor :content
    # The box maximum width
    attr_accessor :max_width
    # The default alignment to use
    attr_accessor :default_align

    def initialize params = {}
      params = {
        :color => :white,
        :content => ''
      }.merge! params
      @color = params[:color]
      @content = params[:content].to_s
    end

    #
    # Adds a line text to this box
    #
    # === Args
    #
    # +line_text+::
    #   The text to add.
    # +params+::
    #   A hash of parameters. Currently supported are:
    #     color: the text color (see #Yummi#COLORS)
    #     width: the text maximum width. Set this to break the lines automatically.
    #
    def add text, params = {}
      params = {
        :width => @max_width + 1,
        :align => @default_align
      }.merge! params
      if params[:width]
        width = params[:width]
        words = text.gsub($/, ' ').split(' ')
        buff = ''
        words.each do |word|
          if buff.size + word.size > width
            _add_ buff, params
            buff = ''
          end
          buff << ' ' unless buff.empty?
          buff << word
        end
        unless buff.empty?
          _add_ buff, params
        end
      else
        text.each_line do |line|
          _add_ line, params
        end
      end
    end

    alias_method :<<, :add

    # Adds a line break to the text.
    def line_break
      @content << $/
    end

    #
    # Prints the #to_s into the given object.
    #
    def print to = $stdout
      to.print to_s
    end

    def to_s
      width = 0
      sizes = []
      content.each_line do |line|
        size = (Yummi::Color::raw line.chomp).size
        sizes << size
        width = [width, size].max
      end
      border = Yummi.colorize('+' + ('-' * width) + '+', color) + $/
      pipe = Yummi.colorize '|', color
      buff = ''
      buff << border
      i = 0
      content.each_line do |line|
        diff = width - sizes[i]
        buff << pipe << line.chomp << (' ' * diff) << pipe << $/
        i += 1
      end
      buff << border
      buff
    end

    private

    def _add_ text, params
      if params[:align] and params[:width]
        text = Yummi::Aligner.align params[:align], text, params[:width]
      end
      @content << Yummi.colorize(text, params[:color])
      line_break
    end

  end

end