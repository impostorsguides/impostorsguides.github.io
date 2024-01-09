#!/usr/bin/env ruby

require "paru/filter"

image_filter = Paru::Filter.run do
  @print_methods = true
  with "Image" do |image|
    # STDERR.puts image.methods.sort

    contents = image.ast_contents
    img_url_node = contents.pop
    img_url = img_url_node.first
    img_url.sub!('/', '')
    img_url_node[0] = img_url
    image.ast_contents << img_url_node
    @print_methods = false
  end
end
