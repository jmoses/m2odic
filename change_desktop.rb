#!/usr/bin/env ruby

require 'rubygems'
require 'rmagick'
require 'plist'
require 'rbosa'
require 'yaml'
require 'fileutils'
require 'pathname'
require 'tempfile'
require 'logger'

logger = Logger.new(STDOUT)

def to_plist( fpath, cts = nil )
  if cts
    File.open( fpath + ".tmp", 'w') do |out|
      out << cts
    end
    FileUtils.mv( fpath + ".tmp", fpath )
  end
  
  `plutil -convert binary1 #{fpath}`
end

def to_xml( fpath )
  `plutil -convert xml1 #{fpath}`
  File.read( fpath )
end

def generate_mirrored( img )
  baseout = File.join( File.dirname(img), '.mirror')
  out = File.join( baseout, File.basename(img) )
  unless File.exists?(baseout)
    FileUtils.mkdir( baseout )
  end
  
  image = Magick::Image.read( img ).first
  image.flop!
  image.write( out )
  out
end

def generate_identifier( key )
  baseout = "/tmp/m2odic-id-#{key}.gif"
  image_list = Magick::ImageList.new
  image_list.new_image( 640, 480 ) do
    self.background_color = "#999999"
  end
  
  text = Magick::Draw.new
  text.font_family = "arial"
  text.pointsize = 52
  text.gravity = Magick::CenterGravity
  text.annotate(image_list, 0, 0, 0, 0, key) do
    self.fill = "#ffffff"
  end
  
  image_list.write( baseout)
  baseout
end

config = {
  :logfile => File.join( File.dirname(__FILE__), '.m2odic.log'),
  :base_bgs => File.dirname(__FILE__),
  :preferences => File.join( Pathname.new("~").expand_path.to_s, "/Library/Preferences/com.apple.desktop.plist" ),
  :normal_display => nil,
  :mirror => false
}

rc_file = File.join( Pathname.new("~").expand_path.to_s, ".m2odic-rc" )

if File.exists?( rc_file )
  logger.debug "Found config file"
  config.merge!( YAML.load( File.read( rc_file ) ) )
end


log = []
if File.exists?( config[:logfile] )
  log = YAML.load( File.read(config[:logfile]) )
end


new_path = ""
pictures = []
Dir["#{config[:base_bgs]}/*"].each do |pic|
  next if File.directory?(pic)
  pictures << pic
end

if pictures.all? {|pic| log.include?(pic) }
  log = []
else
  pictures = pictures.reject {|pic| log.include?(pic) }
end
logger.info "Picking 1 background out of #{pictures.size}"
new_path = pictures[ rand(pictures.size) ]


data = Plist::parse_xml( to_xml( config[:preferences] ) )

if config[:mirror]
  mirror = generate_mirrored(new_path)
end

data["Background"].each_pair do |key,val|
  next if key == 'default'
  
  if key != config[:normal_display].to_s and config[:mirror]
    path = mirror
  else
    path = new_path
  end
  
  if ARGV.include?("identify")
    path = generate_identifier(key)
  end
  
  logger.info "Using #{path} for #{key}"
  
  # puts "Current paths for #{key}"
  # puts val["ImageFilePath"]
  val["ImageFilePath"] = path
  # puts val["NewImageFilePath"]
  val["NewImageFilePath"] = path
end

to_plist(config[:preferences], data.to_plist)

## Force reload of desktop backgrounds.  Yeah!
finder = OSA.app("Finder")
finder.desktop_picture = finder.desktop_picture

log << new_path unless ARGV.include?("identify")

File.open(config[:logfile], 'w') {|out| out << log.to_yaml }
