#
# Reflected XSS Attack Checking Module
# Check whether X-XSS-PROTECTION HTTP header is set to mitigate reflected XSS attacks.
#

$: << "#{File.dirname(__FILE__)}/lib/"
require 'report.ut'
require 'json'

class AntiReflectionChecker
  include ReportUtils
  def initialize(config=$datastore['config'],session_data=$datastore['session'],flag='s')
    @config=config
    if flag=='f'
      begin
        @session_data=File.open(session_data,'r').read 
      rescue =>exp
        log "ERROR: #{exp.to_s}" 
        @session_data=""
      end
    elsif flag=="s"
      @session_data=session_data
    else
      log 'unknow flag' 
      return nil
    end
  end

  def run
    abstain
    header_found = false
    log "Checking for X-XSS-PROTECTION header..."

    begin
      data = JSON.parse(@session_data, {create_additions:false})
      config = JSON.parse(@config, {create_additions:false})
      responses = data['responses']

      responses.each_pair do |k,v|
        if v.scan(/X-XSS-PROTECTION: *1/i) !=[]
          next if not data['requests'][k].lines.first.include? config['whitelist'][0]
          log "Found X-XSS-PROTECTION is being enabled in response ##{k}" 
          header_found = true
          break
        end
      end

      if header_found == false
        advise
        log "X-XSS-PROTECTION is not found"
      end

    rescue => excep
      error
      log "ERROR: #{excep}" 
    end#begin
    
  end #run
end
