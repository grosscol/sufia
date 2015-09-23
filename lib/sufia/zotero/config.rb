module Sufia
  module Zotero
    def self.config
      @config ||= reload_config!
    end

    # parse and set configuration from config/zotero.yml file
    # @return [Hash] with :client_key and :client_secret 
    def self.reload_config!
      @config = YAML.load(ERB.new(IO.read(File.join(Rails.root, 'config', 'zotero.yml'))).result)['zotero']
    end

    def self.publications_url(zotero_userid)
      "/users/#{zotero_userid}/publications/items"
    end
  end
end
