require 'open3'
require 'json'
require 'socket'
require 'timeout'

class Autologin

  def cleanProcs
    mitmdump = `ps -ef | grep mitmdump | grep -v grep | awk '{print $2}'`.to_i
    Process.kill 'KILL', mitmdump if mitmdump > 0
    phantom = `ps -ef | grep phantomjs | grep -v grep | awk '{print $2}'`.to_i
    Process.kill 'KILL', phantom if phantom > 0
  end

  def initialize(config=$datastore['config'],autotime=30)
    @config=config
    @autotime=autotime
  end

  def run
    config = JSON.parse(@config, {create_additions:false})
    if config['logtype'] != "normal" or config['positions']['button']['x'] > 0
      log "No need to autologin"
      return
    end

    cleanProcs

    mitm_in, mitm_out, mitm_err, mitm_thd = Open3.popen3("mitmdump")
    mitm_in.close
    ready = false
    until ready
      begin
        TCPSocket.new('localhost',8080)
        ready = true
      rescue Errno::ECONNREFUSED
        ready = false
      end
    end

    log "mitmdump is started"

    phantom_in, phantom_out, phantom_err = Open3.popen3("phantomjs --proxy=localhost:8080 --ignore-ssl-errors=true #{File.dirname(__FILE__)}/js/autologin.js")
    phantom_in.puts @config
    phantom_in.close

    log "phantomjs is started"
    log "Detecting position of the login form..."

    new_conf = nil
    begin
      Timeout::timeout(@autotime) do
        new_conf = phantom_out.gets
      end
    rescue Timeout::Error
      sock = nil
      begin
        log "Asking phantomjs to stop..."
        sock = TCPSocket.new '127.0.0.1', 4447
        sock.write("GET / HTTP/1.1\n\n")
      rescue
        log "phantomjs is probably still running"
      ensure
        sock.close() if not sock.nil?
      end
    end

    phantom_out.close
    phantom_err.close

    if (not new_conf.nil?) then
      new_conf.chomp!
      valid = false
      begin
        JSON.parse(new_conf, {create_additions:false})
        valid = true
      rescue JSON::ParserError
        valid = false
      end
      $datastore['config'] = new_conf if valid
    end

    begin
      mitmdump = `ps -ef | grep mitmdump | grep -v grep | awk '{print $2}'`.to_i
      log "Asking mitmdump to stop..." if mitmdump > 0
      #log "#{mitmdump}" if mitmdump > 0
      Process.kill 'INT', mitmdump if mitmdump > 0
    rescue
      log "mitmdump is probably still running"
    end

    log "autologin is done"

  end
end
