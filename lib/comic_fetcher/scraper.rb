require 'nokogiri'
require 'open-uri'
require 'date'
require 'digest/md5'

class ComicFetcher::Scraper
  attr_reader :comic, :config, :root_path, :path, :page

  def initialize(comic, config, root_path)
    @comic = comic
    @config = config
    @root_path = root_path
    @path = sub_directories? ? full_path : root_path # set download path
    @page = load_page

    create_folder!
  end

  def sub_directories?
    config['settings']['sub_directories'] # set in config.yml
  end

  def check_hash?
    config['settings']['check_hash'] # set in config.yml
  end

  def full_path
    "#{root_path}/#{comic}"
  end

  def create_folder!
    unless Dir.exists?(path)
      FileUtils.mkdir_p(path)
      FileUtils.chmod_R(0700, path)
    end
  end

  def load_page
    url = config['comics'][comic]['url']
    user_agent = config['settings']['user_agent']
    Nokogiri::HTML(open(url, 'User-Agent' => user_agent))
  end

  def fetch
    filename = generate_filename
    img = open(link_to_img, 'rb') { |read_file| read_file.read }

    if check_hash? # Compare MD5 hashes and filenames
      save_to_disk!(filename, img) if !file_exists?(filename) && unique?(img)
    else # Compare filenames only
      save_to_disk!(filename, img) unless file_exists?(filename)
    end
  end

  def generate_filename
    filename = date + '-' + comic + '.jpg'
    filename.to_s
  end

  def date
    xpath_date = config['comics'][comic]['xpath_date']
    date = page.xpath(xpath_date).first.to_s
    parse_date(date)
  end

  def parse_date(date)
    date = Date.parse(date)
    year = date.strftime('%Y')
    month = date.strftime('%m')
    day = date.strftime('%d')
    "#{year}-#{month}-#{day}"
  end

  def link_to_img
    xpath_img = config['comics'][comic]['xpath_img']
    page.xpath(xpath_img).first.to_s
  end

  def file_exists?(filename)
    File.exists?("#{path}/#{filename}")
  end

  # Compare all files using MD5 hashes
  def unique?(img)
    hash = {}
    key = hash_from_img(img)
    hash[key] = [img]

    Dir.glob("#{path}/**/*", File::FNM_DOTMATCH).each do |filename|
      next if File.directory?(filename)

      key = hash_from_img(IO.read(filename))
      if hash.key?(key)
        hash[key].push(filename)
        puts "Duplicate file found (#{filename})"
        return false
      else
        hash[key] = [filename]
      end
    end
  end

  def hash_from_img(img)
    Digest::MD5.hexdigest(img).to_sym
  end

  def save_to_disk!(filename, img)
    File.open("#{path}/#{filename}", 'wb') do |saved_file|
      puts "Writing a new file: #{filename}"
      saved_file.write(img)
    end
  end
end
