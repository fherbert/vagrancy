require 'sinatra/base'

require 'vagrancy/filestore'
require 'vagrancy/filestore_configuration'
require 'vagrancy/upload_path_handler'
require 'vagrancy/box'
require 'vagrancy/provider_box'
require 'vagrancy/dummy_artifact'
require 'vagrancy/invalid_file_path'

require 'base64'

module Vagrancy
  class App < Sinatra::Base
    set :logging, true
    set :show_exceptions, :after_handler

    error Vagrancy::InvalidFilePath do
      status 403
      env['sinatra.error'].message
    end

    [ '/:username/:name', '/box/:username/:name'].each do |path|
      get path do
        authenticate
        box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)

        status box.exists? ? 200 : 404
        content_type 'application/json'
        box.to_json if box.exists?
      end
    end

    put '/:username/:name/:version/:provider' do
      authenticate
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      provider_box.write(request.body)
      status 200
    end

    get '/:username/:name/:version/:provider' do
      authenticate
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      send_file filestore.file_path(provider_box.file_path) if provider_box.exists?
      status provider_box.exists? ? 200 : 404
    end

    delete '/:username/:name/:version/:provider' do
      authenticate
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      status provider_box.exists? ? 200 : 404
      provider_box.delete
    end

    # vagrant cloud emulation for using with packer

    post '/box/:username/:name/versions' do
      status 200
      payload = JSON.parse(request.body.read)
      logger.info payload["version"]
      content_type 'application/json'
      payload["version"].to_json
    end

    post '/box/:username/:name/version/:version/providers' do
      status 200
      payload = JSON.parse(request.body.read)
      content_type 'application/json'
      payload["provider"].to_json
    end

    get '/box/:username/:name/version/:version/provider/:provider/upload' do
      authenticate
      status 200
      content_type 'application/json'
      { :upload_path => "#{request.scheme}://#{request.host_with_port}/#{params[:username]}/#{params[:name]}/#{params[:version]}/#{params[:provider]}?access_token=#{params[:access_token]}"}.to_json
    end

    delete '/box/:username/:name/version/:version/provider/:provider' do
      # Post-Processor Vagrant Cloud API DELETE
      # Deleting provider
      status 200
    end

    put '/box/:username/:name/version/:version/release' do
      # Release version, for now we do nothing
      authenticate
      status 200
    end

    # End of vagrant cloud emulation

    # Atlas emulation, no authentication
    get '/api/v1/authenticate' do
      status 200
    end

    post '/api/v1/artifacts/:username/:name/vagrant.box' do
      authenticate
      content_type 'application/json'
      UploadPathHandler.new(params[:name], params[:username], request, filestore).to_json
    end

    get '/api/v1/artifacts/:username/:name' do
      authenticate
      status 200
      content_type 'application/json'
      DummyArtifact.new(params).to_json
    end

    def filestore 
      path = FilestoreConfiguration.new.path
      Filestore.new(path)
    end

    def authenticate
      token = Base64.strict_encode64(FilestoreConfiguration.new.access_token)
      halt 401 unless token == params[:access_token]
    end
  end
end
