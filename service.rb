require 'sinatra'

adoctor_supported = false
begin
  require 'asciidoctor'
  extensions = ENV['SHIMGO_ASCIIDOCTOR_REQUIRES']
  unless extensions.nil?
    extensions.split(',').each do |path|
      begin
        require path
      rescue ::LoadError
        $stderr.puts %(asciidoctor: FAILED: '#{path}' could not be loaded)
      rescue ::SystemExit
        # ignore
      end
    end
  end
  adoctor_supported = true
rescue LoadError
  adoctor_supported = false
end

def capture_stderr
  $stderr = StringIO.new
  yield
  $stderr.string
end

enable :quiet
disable :logging
set :environment, :production
set :bind, 'localhost'
set :port, ARGV[0]

get '/' do
  response = { status: 'running', asciidoctor: adoctor_supported }
  content_type('application/json')
  return JSON.generate(response)
end

get '/support/:format' do
  content_type('text/plain')
  if params['format'] == 'asciidoctor'
    return "supported\n"
  else
    status 400
    return "#{params['format']} is not supported\n"
  end
end

post '/asciidoctor' do
  request.body.rewind # in case someone already read it

  content = ''
  captured_output = capture_stderr do
    content = Asciidoctor.convert request.body.read,
                                  header_footer: false,
                                  safe: Asciidoctor::SafeMode::SAFE,
                                  trace: true
  end

  response = { info: if captured_output.nil?
                       ''
                     else
                       captured_output.gsub(' <stdin>:', '')
                     end,
               content: content }
  content_type('application/json')
  return JSON.generate(response)
end
