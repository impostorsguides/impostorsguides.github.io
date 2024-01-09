require 'paru/pandoc'

converter = Paru::Pandoc.new

converter.configure do
  from 'html'
  to 'pdf'
  output 'output.pdf'
  resource_path 'assets/images'
  filter "filter_remove_slashes_from_images.rb"
  css "pdf_styles.css"
  pdf_engine 'wkhtmltopdf'
end

converter.convert_file(ARGV[0])
