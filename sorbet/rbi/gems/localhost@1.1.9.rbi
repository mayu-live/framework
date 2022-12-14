# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `localhost` gem.
# Please instead update this file by running `bin/tapioca gem localhost`.

# source:////lib/localhost/version.rb#21
module Localhost; end

# Represents a single public/private key pair for a given hostname.
#
# source:////lib/localhost/authority.rb#26
class Localhost::Authority
  # Create an authority forn the given hostname.
  #
  # @return [Authority] a new instance of Authority
  #
  # source:////lib/localhost/authority.rb#61
  def initialize(hostname = T.unsafe(nil), root: T.unsafe(nil)); end

  # The public certificate.
  #
  # source:////lib/localhost/authority.rb#114
  def certificate; end

  # The public certificate path.
  #
  # source:////lib/localhost/authority.rb#90
  def certificate_path; end

  # source:////lib/localhost/authority.rb#179
  def client_context(*args); end

  # source:////lib/localhost/authority.rb#80
  def dh_key; end

  # source:////lib/localhost/authority.rb#76
  def ecdh_key; end

  # The hostname of the certificate authority.
  #
  # source:////lib/localhost/authority.rb#72
  def hostname; end

  # The private key.
  #
  # source:////lib/localhost/authority.rb#95
  def key; end

  # source:////lib/localhost/authority.rb#99
  def key=(key); end

  # The private key path.
  #
  # source:////lib/localhost/authority.rb#85
  def key_path; end

  # source:////lib/localhost/authority.rb#189
  def load(path = T.unsafe(nil)); end

  # The certificate name.
  #
  # source:////lib/localhost/authority.rb#104
  def name; end

  # source:////lib/localhost/authority.rb#108
  def name=(name); end

  # source:////lib/localhost/authority.rb#209
  def save(path = T.unsafe(nil)); end

  # source:////lib/localhost/authority.rb#154
  def server_context(*arguments); end

  # The certificate store which is used for validating the server certificate.
  #
  # source:////lib/localhost/authority.rb#145
  def store; end

  class << self
    # Fetch (load or create) a certificate with the given hostname.
    # See {#initialize} for the format of the arguments.
    #
    # source:////lib/localhost/authority.rb#48
    def fetch(*arguments, **options); end

    # List all certificate authorities in the given directory:
    #
    # source:////lib/localhost/authority.rb#32
    def list(root = T.unsafe(nil)); end

    # source:////lib/localhost/authority.rb#27
    def path; end
  end
end

# source:////lib/localhost/authority.rb#74
Localhost::Authority::BITS = T.let(T.unsafe(nil), Integer)

# source:////lib/localhost/authority.rb#151
Localhost::Authority::SERVER_CIPHERS = T.let(T.unsafe(nil), String)

# source:////lib/localhost/version.rb#22
Localhost::VERSION = T.let(T.unsafe(nil), String)
