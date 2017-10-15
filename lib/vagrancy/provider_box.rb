module Vagrancy
  class ProviderBox

    def initialize(provider, version, box, filestore, request)
      @provider = provider
      @box = box
      @filestore = filestore
      @request = request
      @version = version
    end

    def to_h
      exists? ? {:name => @provider, :url => url} : {}
    end

    def write(stream)
      @filestore.write(file_path, stream)
    end

    def read
      @filestore.read(file_path)
    end

    def delete
      @filestore.delete(file_path) if exists?
    end

    def exists?
      @filestore.exists?(file_path)
    end

    def url
      vars = @request.params
      if vars.has_key?('access_token')
        q = '?access_token=' + vars['access_token']
      else
        q = ''
      end
      base_site + '/' + path + q
    end

    def file_path
      path + '/box'
    end

    private 

    def base_site
      @request.scheme + '://' + @request.host + ':' + @request.port.to_s
    end

    def path
      @box.path + '/' + @version + '/' + @provider
    end

  end
end
