require 'openssl'
require_relative 'util'

# Digest algorithms supported "out of the box"
DIGEST_ALGORITHMS = {
    # SHA 1
    'http://www.w3.org/2000/09/xmldsig#sha1' => OpenSSL::Digest::SHA1.new,
    # GOST R 34.11-94
    'http://www.w3.org/2001/04/xmldsig-more#gostr3411' => gost_engine.digest('md_gost94'),
}

# Class that holds +OpenSSL::Digest+ instance with some meta information for digesting in XML.
class DigestAlgorithm

  # You may pass either a one of +:sha1+, +:sha256+ or +:gostr3411+ symbols
  # or +Hash+ with keys +:id+ with a string, which will denote algorithm in XML Reference tag
  # and +:digester+ with instance of class with interface compatible with +OpenSSL::Digest+ class.
  def initialize(algorithm)
    if algorithm.kind_of? String
      @digest_info = { url: algorithm }
      @digest_info[:digester] = DIGEST_ALGORITHMS[algorithm]
      raise "Unknown digest algorithm: #{algorithm}"  unless @digest_info[:digester]
    else
      @digest_info = algorithm
    end
  end

  # Digest
  def digest(message)
    self.digester.digest(message)
  end

  alias call digest

  # Returns +OpenSSL::Digest+ (or derived class) instance
  def digester
    @digest_info[:digester].reset
  end

  # Identidier (for specifying in XML +DigestMethod+ node +Algorithm+ attribute)
  def url
    @digest_info[:url]
  end

end
