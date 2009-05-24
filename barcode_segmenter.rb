
require 'rubygems'

require 'camellia'
require 'mini_magick'
require 'debuggable'
require 'argument_tools'

BarcodeSegmenterError = Class.new(StandardError)

class BarcodeSegmenter
  
  include Camellia
  include Debuggable
  include ArgumentTools

  attr_accessor :file_path, :file_output_path
  
  def initialize(args={})
    assign_arguments(args, [:file_path, :file_output_path, :debug_mode])
    ensure_exists!([:file_path, :file_output_path])
    filter_and_output
  end
  
  def filter_and_output
    image = CamImage.new

    # load picture, only 24 bit (truecolor) BMP images
    
    magick_image = MiniMagick::Image.from_file(file_path)
    magick_image.depth "24"
    magick_image.format "bmp"
    magick_image.write "#{file_path}.bmp" 
    
    image.load_bmp("#{file_path}.bmp")

    # convert to YUV encoding: http://en.wikipedia.org/wiki/YUV
    yuv = image.to_yuv

    # consider only the Y plane (black)
    yuv.set_roi(CamROI.new(1, 0, 0, yuv.width, yuv.height)) 

    # threshold and encode
    threshold = yuv.encode_threshold_inv(150)

    # labeling
    blobs = threshold.labeling!
    
    unless blobs
      raise BarcodeSegmenterError, "No barcode detected!"
    end
    
    out "#{blobs.nb_blobs} blobs detected before filtering"

    # 10 % of the entire image is "too large"
    too_large_area = 0.10 * (yuv.width * yuv.height)
    # 50 pixels is "too small"
    too_small_area = 50 

    # filter out too small and too large blobs
    filtered = blobs.sort { |a,b| b.surface <=> a.surface }.
      reject { |b| b.surface < too_small_area || b.surface > too_large_area }

    out "#{filtered.length} blobs after filtering"
    
    if filtered.length == 0
      raise BarcodeSegmenterError, "No barode detected!"
    end

    b_left_small = yuv.width
    b_left_large = 0
    b_top_small = yuv.height
    b_top_large = 0

    filtered.each_with_index do |b, i| 
      out "Blob #{i}: Surface area: #{b.surface}, at (#{b.cx}, #{b.cy})"
      b_left_small = b.left if b.left < b_left_small
      b_left_large = b.left + b.width if b.left > b_left_large
      b_top_small = b.top if b.top < b_top_small
      b_top_large = b.top + b.height if b.top > b_top_large
    end
    
    #increase bounding box size by 30 pixel square
    b_left_small -= 30
    b_top_small -= 30
    b_left_large += 30
    b_top_large += 30

    out "Bounding box: (#{b_left_small}, #{b_top_small}) to  (#{b_left_large}, #{b_top_large})."

    if debug_mode?      
      # draw rectangle on all detected blobs 
      filtered.each {|b| image.draw_rectangle(b.left,b.top,b.left+b.width-1,b.top+b.height-1,cam_rgb(255,0,0))}

      # draw blue rectangle on the bounding box
      image.draw_rectangle(b_left_small, b_top_small, b_left_large, b_top_large, cam_rgb(0, 0, 255))
      
      # save the resulting picture
      image.save_bmp("out.bmp")
    end
    
    magick_image = MiniMagick::Image.from_file(file_path)
    magick_image.crop "#{b_left_large - b_left_small}x#{b_top_large - b_top_small}+#{b_left_small}+#{b_top_small}"
    magick_image.write file_output_path
  ensure
    system("rm #{"#{file_path}.bmp"}")
    
  end
    
end

BarcodeSegmenter.new :file_path => ARGV[0], 
  :file_output_path => ARGV[1],
  :debug_mode => ARGV[2] == "debug=true" ? true : false
    
