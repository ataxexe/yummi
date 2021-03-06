#                         The MIT License
#
# Copyright (c) 2013 Marcelo Guimarães <ataxexe@gmail.com>
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

require 'ostruct'
require_relative 'row_extractor'

module Yummi
  # A Table that supports colorizing title, header, values and also formatting the values.
  class Table
    include Yummi::OnBox
    include Yummi::RowExtractor

    # The table title
    attr_accessor :title
    # The table description
    attr_accessor :description
    # Default align. #Yummi#Aligner should respond to it.
    attr_accessor :default_align
    # Aliases that can be used by formatters and colorizers instead of numeric indexes.
    # The aliases are directed mapped to their respective index in this array
    attr_accessor :aliases
    # The table colspan
    attr_accessor :colspan
    # The table colors. This Map should have colors for the following elements:
    #
    # * Title: using :title key
    # * Header: using :header key
    # * Values: using :value key
    #
    # The colors must be supported by #Yummi#Color#parse or defined in #Yummi#Color#COLORS
    attr_accessor :style
    # The table layout (horizontal or vertical)
    attr_reader :layout
    # The table header
    attr_reader :header

    #
    # Creates a new table. A hash containing the style properties may be given to override
    # the defaults.
    #
    # * Title (title): none
    # * Description (description): none
    # * Header (header): none
    #
    # Hash in "style" key:
    #
    # * Title color (title): bold.yellow
    # * Header color (header): bold.blue
    # * Values color (color): none
    # * Colspan (colspan): 2
    # * Default Align (align): right and first element to left
    #
    def initialize(params = {})
      params = OpenStruct::new params
      params.style ||= {}
      @data = []
      @header = []
      @title = (params.title or nil)
      @description = (params.description or nil)
      @style = {
        :title => (params.style[:title] or 'bold.yellow'),
        :description => (params.style[:description] or 'bold.black'),
        :header => (params.style[:header] or 'bold.blue'),
        :value => (params.style[:color] or nil)
      }

      @colspan = (params.colspan or 2)
      @layout = (params.layout or :horizontal)
      @default_align = (params.align or :right)
      @aliases = []

      @align = [:left]
      @components = {}
      @contexts = [:default]
      _define_ :default
      @current_context = :default

      self.header = params.header if params.header
    end

    # Indicates that the table should not use colors.
    def no_colors
      @style = {
        :title => nil,
        :header => nil,
        :value => nil
      }
      @no_colors = true
    end

    #
    # Groups definitions for a specified group of rows at the bottom of the table.
    # Every customization can be used (formatter/colorizer for null values, for rows
    # and columns). Customizations must be done in the given block.
    #
    # Subsequent calls to this method creates different groups. 
    #
    # === Args
    #   +:rows+:: The number of rows to group using the customizations in the block
    #
    # === Examples
    #
    #   table.bottom :rows => 3 do
    #     table.colorize :subtotal, :with => :green
    #     table.format :approved, :using => Yummi::Formatters::boolean
    #   end
    #   table.bottom { table.colorize :total, :with => :white }
    #
    def bottom(params = {}, &block)
      index = @contexts.size
      _context_ index, params, &block
    end

    #
    # Groups definitions for a specified group of rows at the top of the table.
    # Every customization can be used (formatter/colorizer for null values, for rows
    # and columns). Customizations must be done in the given block.
    #
    # Subsequent calls to this method creates different groups. 
    #
    # === Args
    #   +:rows+:: The number of rows to group using the customizations in the block
    #
    # === Examples
    #
    #   table.top :rows => 3 do
    #     table.colorize :subtotal, :with => :green
    #     table.format :approved, :using => Yummi::Formatters::boolean
    #   end
    #   table.top { table.colorize :total, :with => :white }
    #
    def top(params = {}, &block)
      _context_ 0, params, &block
    end

    # Sets the table print layout.
    def layout=(layout)
      @layout = layout.to_sym
      case @layout
        when :horizontal
          @default_align = :right
        when :vertical
          @default_align = :left
        else
          raise 'Unsupported layout'
      end
    end

    # Retrieves the row at the given index
    def row(index)
      @data[index]
    end

    # Retrieves the column at the given index. Aliases can be used
    def column(index)
      index = parse_index(index)
      columns = []
      @data.each do |row|
        columns << row_to_array(row)[index].value
      end
      columns
    end

    #
    # Sets the table header. If no aliases are defined, they will be defined as the texts
    # in lowercase with line breaks and spaces replaced by underscores.
    #
    # Defining headers also limits the printed column to only columns that has a header
    # (even if it is empty).
    #
    # === Args
    #
    # +header+::
    #   Array containing the texts for displaying the header. Line breaks are supported
    #
    # === Examples
    #
    #   table.header = ['Name', 'Email', 'Work Phone', "Home\nPhone"]
    #
    # This will create the following aliases: :key, :email, :work_phone and :home_phone
    #
    def header=(header)
      header = [header] unless header.respond_to? :each
      @header = normalize(header)
      @aliases = header.map do |n|
        n.downcase.gsub(' ', '_').gsub("\n", '_').to_sym
      end if @aliases.empty?
    end

    #
    # Sets the align for a column in the table. #Yummi#Aligner should respond to it.
    #
    # === Args
    #
    # +index+::
    #   The column indexes or its aliases
    # +type+::
    #   The alignment type
    #
    # === Example
    #
    #   table.align :description, :left
    #   table.align [:value, :total], :right
    #
    def align(indexes, type)
      [*indexes].each do |index|
        index = parse_index(index)
        raise Exception::new "Undefined column #{index}" unless index
        @align[index] = type
      end
    end

    #
    # Adds a component to colorize the entire row (overrides column color).
    # The component must respond to +call+ with the index and the row as the arguments and
    # return a color or +nil+ if default color should be used. A block can also be used.
    #
    # === Example
    #
    #   table.colorize_row { |i, row| :red if row[:value] < 0 }
    #
    def colorize_row(params = nil, &block)
      obj = extract_component(params, &block)
      component[:row_colorizer] = obj
    end

    # Sets the table data
    def data=(data)
      @data = data
    end

    #
    # Adds the given data as a row. If the argument is a hash, its keys will be used
    # to match header alias for building the row data.
    #
    def add(row)
      @data << row
    end

    alias_method :<<, :add

    #
    # Sets a component to colorize a column.
    #
    # The component must respond to +call+ with the column value (or row if used with
    # #using_row) as the arguments and return a color or +nil+ if default color should be
    # used. A block can also be used.
    #
    #
    # === Args
    #
    # +indexes+::
    #   The column indexes or its aliases
    # +params+::
    #   A hash with params in case a block is not given:
    #     - :using defines the component to use
    #     - :with defines the color to use (to use the same color for all columns)
    #
    # === Example
    #
    #   table.colorize :description, :with => :magenta
    #   table.colorize([:value, :total]) { |value| :red if value < 0 }
    #
    def colorize(indexes, params = {}, &block)
      [*indexes].each do |index|
        index = parse_index(index)
        if index
          obj = extract_component(params, &block)
          component[:colorizers][index] = obj
        else
          colorize_null params, &block
        end
      end
    end

    #
    # Defines a colorizer to null values.
    #
    # === Args
    #
    # +params+::
    #   A hash with params in case a block is not given:
    #     - :using defines the component to use
    #     - :with defines the format to use
    #
    def colorize_null(params = {}, &block)
      component[:null_colorizer] = (params[:using] or block)
      component[:null_colorizer] ||= proc do |value|
        params[:with]
      end
    end

    #
    # Sets a component to format a column.
    #
    # The component must respond to +call+ with the column value
    # as the arguments and return a color or +nil+ if default color should be used.
    # A block can also be used.
    #
    # === Args
    #
    # +indexes+::
    #   The column indexes or its aliases
    # +params+::
    #   A hash with params in case a block is not given:
    #     - :using defines the component to use
    #     - :with defines the format to use (to use the same format for all columns)
    #
    # === Example
    #
    #   table.format :value, :with => '%.2f'
    #   table.format [:value, :total], :with => '%.2f'
    #
    def format(indexes, params = {}, &block)
      [*indexes].each do |index|
        index = parse_index(index)
        if index
          component[:formatters][index] = (params[:using] or block)
          component[:formatters][index] ||= proc do |ctx|
            params[:with] % ctx.value
          end
        else
          format_null params, &block
        end
      end
    end

    #
    # Defines a formatter to null values.
    #
    # === Args
    #
    # +params+::
    #   A hash with params in case a block is not given:
    #     - :using defines the component to use
    #     - :with defines the format to use
    #
    def format_null(params = {}, &block)
      component[:null_formatter] = (params[:using] or block)
      component[:null_formatter] ||= proc do |value|
        params[:with] % value
      end
    end

    #
    # Prints the #to_s into the given object.
    #
    def print(to = $stdout)
      to.print to_s
    end

    #
    # Return a colorized and formatted table.
    #
    def to_s
      header_output = build_header_output
      data_output = build_data_output

      string = ''
      string << Yummi.colorize(@title, @style[:title]) << $/ if @title
      string << Yummi.colorize(@description, @style[:description]) << $/ if @description
      table_data = header_output + data_output
      if @layout == :vertical
        # don't use array transpose because the data may differ in each line size
        table_data = rotate table_data
      end
      string << content(table_data)
    end

    #
    # Calculates the table width using the rendered lines
    #
    def width
      string = to_s
      max_width = 0
      string.each_line do |line|
        max_width = [max_width, line.uncolored.chomp.size].max
      end
      max_width
    end

    private

    def extract_component(params, &block)
      if params and params[:using]
        params[:using]
      elsif params and params[:with]
        proc { |v| params[:with] }
      else
        block
      end
    end

    def _define_(context)
      @components[context] = {
        :formatters => [],
        :colorizers => [],
        :row_colorizer => nil,
      }
    end

    def _context_(index, params, &block)
      params ||= {}
      rows = (params[:rows] or 1)
      ctx = @contexts.size
      _define_ ctx
      @contexts.insert(index, {:id => ctx, :rows => rows})

      @current_context = ctx
      block.call if block
      @current_context = :default
    end

    #
    # Gets the content string for the given color map and content
    #
    def content (data)
      string = ''
      data.each_index do |i|
        row = data[i]
        row.each_index do |j|
          column = row[j]
          column ||= {:value => nil, :color => nil}
          width = max_width data, j
          alignment = (@align[j] or @default_align)
          value = Aligner.align alignment, column[:value].to_s, width
          value = Yummi.colorize value, column[:color] unless @no_colors
          string << value
          string << (' ' * @colspan)
        end
        string.strip! << $/
      end
      string
    end

    #
    # Builds the header output for this table.
    #
    # Returns the color map and the header.
    #
    def build_header_output
      output = []

      @header.each do |line|
        _data = []
        line.each do |h|
          _data << {:value => h, :color => @style[:header]}
        end
        output << _data
      end
      output
    end

    # maps the context for each row
    def build_row_contexts
      rows = @data.size
      row_contexts = [:default] * rows
      offset = 0
      @contexts.each do |ctx|
        if ctx == :default
          break
        end
        size = ctx[:rows]
        row_contexts[offset...(size + offset)] = [ctx[:id]] * size
        offset += size
      end
      @contexts.reverse_each do |ctx|
        if ctx == :default
          break
        end
        size = ctx[:rows]
        row_contexts[(rows - size)...rows] = [ctx[:id]] * size
        rows -= size
      end
      row_contexts
    end

    #
    # Builds the data output for this table.
    #
    # Returns the color map and the formatted data.
    #
    def build_data_output
      output = []
      row_contexts = build_row_contexts
      @data.each_index do |row_index|
        # sets the current context
        @current_context = row_contexts[row_index]
        row = row_to_array(@data[row_index], row_index)
        _row_data = []
        row.each_index do |col_index|
          next if not @header.empty? and @header[0].size < col_index + 1
          column = row[col_index]
          colorizer = component[:colorizers][col_index]
          color = if component[:null_colorizer] and column.value.nil?
            component[:null_colorizer].call(column)
          elsif colorizer
            colorizer.call(column)
          else
            @style[:value]
          end
          formatter = if column.value.nil?
            @null_formatter
          else
            component[:formatters][col_index]
          end
          value = if formatter
            formatter.call(column)
          else
            column.value
          end
          _row_data << {:value => value, :color => color}
        end
        row_colorizer = component[:row_colorizer]
        if row_colorizer
          row_color = row_colorizer.call row.first
          _row_data.collect! { |data| data[:color] = row_color; data } if row_color
        end

        _row_data = normalize(
          _row_data,
          :extract => proc do |data|
            data[:value].to_s
          end,
          :new => proc do |value, data|
            {:value => value, :color => data[:color]}
          end
        )
        _row_data.each do |_row|
          output << _row
        end
      end
      output
    end

    def row_to_array (row, row_index = nil)
      message_name = "extract_row_from_#{row.class.to_s.downcase}".to_sym
      message_name = :extract_row_from_object unless respond_to? message_name
      send(message_name, row, row_index)
    end

    def component
      @components[@current_context]
    end

    def normalize(row, params = {})
      params[:extract] ||= proc do |value|
        value.to_s
      end
      params[:new] ||= proc do |extracted, value|
        extracted
      end
      max = 0
      row.each_index do |i|
        max = [max, params[:extract].call(row[i]).split("\n").size].max
      end
      result = []
      max.times { result << [] }
      row.each_index do |i|
        names = params[:extract].call(row[i]).split("\n")
        names.each_index do |j|
          result[j][i] = params[:new].call(names[j], row[i])
        end
      end
      result
    end

    def parse_index(value)
      return value if value.is_a? Fixnum
      (@aliases.index(value) or @aliases.index(value.to_sym))
    end

    def max_width(data, column)
      max = 0
      data.each do |row|
        var = row[column]
        var ||= {}
        max = [var[:value].to_s.length, max].max
      end
      max
    end

    def rotate(data)
      new_data = []
      data.each_index do |i|
        data[i].each_index do |j|
          new_data[j] ||= []
          new_data[j][i] = data[i][j]
        end
      end
      new_data
    end

  end

  class TableContext < Yummi::Context

    attr_reader :row_index, :column_index

    def initialize(params)
      @row_index = params[:row_index]
      @column_index = params[:column_index]
      @value = params[:value]
      @obj = params[:obj]
    end

  end

end
