require 'net/imap'

module Mailman
  module Receiver
    # Receives messages using IMAP, and passes them to a {MessageProcessor}.
    class IMAP

      # @return [Net::IMAP] the IMAP connection
      attr_reader :connection, :username, :password, :server

      # @param [Hash] options the receiver options
      # @option options [MessageProcessor] :processor the processor to pass new
      #   messages to
      # @option options [String] :server the server to connect to
      # @option options [Integer] :port the port to connect to
      # @option options [String] :username the username to authenticate with
      # @option options [String] :password the password to authenticate with
      def initialize(options)
        @processor, @username, @password, @server, @filter, @port = nil, nil, nil, nil, ["NEW"], 143

        @processor = options[:processor] if options.has_key? :processor
        @username =  options[:username]  if options.has_key? :username
        @password =  options[:password]  if options.has_key? :password
        @filter =    options[:filter]    if options.has_key? :filter
        @port =      options[:port]      if options.has_key? :port
        @options = options
        @server = options[:server]       if options.has_key? :server
        @use_ssl = options[:ssl]||false
      end

      # Connects to the IMAP server.
      def connect
        @connection = Net::IMAP.new(@options[:server], :port => @port, :ssl => @use_ssl)

        Mailman.logger.info "CONNECTING TO #{@server}, #{@username} #{@password}"
        @connection.authenticate(@options[:authenticate_with]||'LOGIN', @username, @password)
        unless @connection.list('', '%').any?{|mailbox| mailbox.name == 'Processed'}
          @connection.create('Processed')
        end
        Mailman.logger.info "Connection established"
        @connection.select 'INBOX'
      end

      # Disconnects from the IMAP server.
      def disconnect
        @connection.logout
      end

      # Iterates through new messages, passing them to the processor, and
      # deleting them.
      def get_messages
        @connection.uid_search(@filter).each do |message|
          puts "PROCESSING MESSAGE #{message}"
          body=@connection.uid_fetch(message,"RFC822")[0].attr["RFC822"]
          @processor.process(body, @options)
          @connection.uid_copy(message, 'Processed')

          @connection.uid_store(message,"+FLAGS",[:Deleted])
        end
        @connection.expunge
        #@connection.delete_all
      end

    end
  end
end
