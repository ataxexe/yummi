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

require 'optparse'
require_relative '../lib/yummi'

opt = OptionParser::new

@basedir = File.join(ENV['HOME'], '*')

@table = Yummi::Table::new
# setting the header sets the aliases automaically
@table.header = ['Name', 'Size', 'Directory']
# sets the title
@table.title = 'Files in home folder'
# aligns the first column to the left
@table.align :name, :left
# formats booleans using Yes or No
@table.format :directory, :using => Yummi::Formatter.yes_or_no
# formats size for easily reading
@table.format :size, :using => Yummi::Formatter.bytes

@table.row_colorizer Yummi::IndexedDataColorizer.odd :with => :intense_gray
@table.row_colorizer Yummi::IndexedDataColorizer.even :with => :intense_white

opt.on '--basedir BASEDIR', 'Selects the basedir to list files' do |basedir|
  @basedir = basedir
end
opt.on '--help', 'Prints this message' do
  puts opt
  exit 0
end

opt.parse ARGV
files = Dir[@basedir]
data = []
files.each do |f|
  data << [f, File.size(f), File.directory?(f)]
end
@table.data = data
@table.print
