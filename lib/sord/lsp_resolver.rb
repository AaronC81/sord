require 'json'
require 'timeout'
require 'sord/logging'

module Sord
  class LspResolver
    attr_accessor :io

    def initialize
      @next_id = 1
    end

    def send_message(hash)
      json = hash.to_json
      message = "Content-Length: #{json.length}\r\n\r\n#{json}"
      io.write(message)
    end

    def send_request(method, params)      
      send_message({
        jsonrpc: '2.0',
        id: @next_id,
        method: method,
        params: params
      })
      @next_id += 1

      read_message
    end

    def send_notification(method, params)      
      send_message({
        jsonrpc: '2.0',
        method: method,
        params: params
      })
    end

    def read_message
      raise "malformed response" unless /^Content-Length: (\d+)\r\n$/ === io.gets
      length = $1.to_i

      io.gets # Throw away the line with just \r\n

      JSON.parse(io.read(length))
    end

    def send_initialize(dir)
      send_request('initialize', {
        processId: nil,
        rootUri: "file://#{dir}",
        rootPath: nil,
        capabilities: {},
        trace: "verbose",
        workspaceFolders: [
          {name: 'sordLsp', uri: "file://#{dir}"}
        ]
      })
    end

    def send_initialized
      send_notification('initialized', {})
    end

    def send_did_open(file)
      send_notification('textDocument/didOpen', {
        textDocument: {
          uri: "file://#{file}",
          version: 1,
          languageId: 'ruby',
          text: File.read(file)
        }
      })
    end

    # TODO: only accept suggestions which match (::)?(identifier::*)(WHAT_WAS_MISSING)
    def diagnostics_for_file(file)
      self.io = IO.popen("srb t . --no-config --lsp --disable-watchman", 'r+')
      send_initialize(Dir.pwd)

      send_initialized

      send_did_open("#{Dir.pwd}/#{file}")

      loop do
        Timeout::timeout(2) do
          msg = read_message
          return msg['params'] if msg['params']['uri'] == "file://#{Dir.pwd}/#{file}"
        end
      end
    end

    def unresolvable_constants_for_file(file)
      diagnostics_for_file(file)['diagnostics']
        .select { |x| x['code'] == 5002 }
        .map do |x|
          {
            'range' => x['range'],
            'message' => x['message'],
            'constant' => x['message'] \
              .match(/^Unable to resolve constant `(.+)`$/).captures.first,
            'suggestions' => x['relatedInformation'].map do |i|
              i['message'].match(/^Did you mean: `(.+)`\?$/)&.captures&.first
            end.compact
          } 
        end
    end

    def replace_unresolvable_constants(file)
      lines = File.read(file).lines.map(&:chomp)

      unresolvable_constants_for_file(file).each do |unresolvable|
        replacements = unresolvable['suggestions'].map do |suggestion|
          [
            suggestion,
            suitable_resolution_for_constant?(unresolvable['constant'],
              suggestion)
          ]
        end.to_h

        # If there is exactly one valid resolution, perform the replacement
        if replacements.values.count(true) == 1
          replacement = replacements.rassoc(true).first

          r_start = unresolvable['range']['start']
          r_end = unresolvable['range']['end']
          raise if r_start['line'] != r_end['line']

          lines[r_start['line']][r_start['character']..r_end['character']] = replacement

          Logging.infer("Inferred missing constant #{unresolvable['constant']}: #{replacement}")
        else
          Logging.info("Discarded possible inferences for #{unresolvable['constant']}: #{replacements.keys.inspect}")
        end
      end
    end

    def suitable_resolution_for_constant?(original, replacement)
      replacement.end_with?("::#{original}")
    end
  end
end
