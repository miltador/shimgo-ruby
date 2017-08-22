require 'sinatra'

adoctor_supported = false
begin
  require 'asciidoctor'
  adoctor_supported = true
rescue LoadError
  adoctor_supported = false
end

def capture_stderr
  # The output stream must be an IO-like object. In this case we capture it in
  # an in-memory IO object so we can return the string value. You can assign any
  # IO object here.
  previous_stderr = $stderr
  $stderr = StringIO.new
  yield
  $stderr.string
ensure
  # Restore the previous value of stderr (typically equal to STDERR).
  $stderr = previous_stderr
end

set :bind, 'localhost'
set :port, 1515
set :threaded, true
set :quiet, true
set :logging, false

get '/' do
  response = { status: 'running', asciidoctor: adoctor_supported }
  content_type('application/json')
  return JSON.generate(response)
end

get '/support/:format' do
  content_type('text/plain')
  if params['format'] == 'asciidoctor'
    return 'supported\n'
  else
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
                                  requires: (
                                  if ENV['SHIMGO_ASCIIDOCTOR_REQUIRES'].nil?
                                    []
                                  else
                                    ENV['SHIMGO_ASCIIDOCTOR_REQUIRES']
                                        .split(',')
                                  end)
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