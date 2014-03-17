require 'fileutils'
require 'yaml'

class ComicFetcher
  attr_reader :config, :root_path

  CONFIG_PATH = '../config/config.yml'

  def initialize
    @config = load_config
    @root_path = root_path
  end

  def load_config
    path = File.expand_path(CONFIG_PATH, current_path)
    YAML.load_file(path)
  end

  def root_path
    path = config['settings']['directory']
    File.expand_path(path, current_path).to_s
  end

  def current_path
    File.dirname(__FILE__)
  end

  def fetch(comic)
    s = Scraper.new(comic, config, root_path)
    s.fetch
  end

  def fetch_all
    config['comics'].each do |key, value|
      fetch(key.to_s)
    end
  end
end

require 'comic_fetcher/scraper'
