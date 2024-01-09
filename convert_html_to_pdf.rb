require 'paru/pandoc'
require 'byebug'

converter = Paru::Pandoc.new

converter.configure do
  from 'html'
  to 'pdf'
  output 'output.pdf'
  resource_path 'assets/images'
  filter "filter_remove_slashes_from_images.rb"
  filter "filter_update_target_blank2.rb"
  css "pdf_styles.css"
end

converter.convert_file(ARGV[0])
