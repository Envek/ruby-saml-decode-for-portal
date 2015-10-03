require 'openssl'
require_relative 'util'

SIGNATURE_ALGORITHMS = {
    # SHA 1
    'http://www.w3.org/2000/09/xmldsig#rsa-sha1' => OpenSSL::Digest::SHA1.new,
    # GOST R 34.10-94
    'http://www.w3.org/2001/04/xmldsig-more#gostr34102001-gostr3411' => gost_engine.digest('md_gost94'),
}

# Class that holds +OpenSSL::Digest+ instance with some meta information for digesting in XML.
class SignatureAlgorithm

  # You may pass either a one of +:sha1+, +:sha256+ or +:gostr3411+ symbols
  # or +Hash+ with keys +:id+ with a string, which will denote algorithm in XML Reference tag
  # and +:digester+ with instance of class with interface compatible with +OpenSSL::Digest+ class.
  def initialize(algorithm)
    if algorithm.kind_of? String
      @digest_info = { url: algorithm }
      @digest_info[:digester] = SIGNATURE_ALGORITHMS[algorithm]
      raise "Unknown signature algorithm: #{algorithm}"  unless @digest_info[:digester]
    else
      @digest_info = algorithm
    end
  end

  # Returns +OpenSSL::Digest+ (or derived class) instance
  def digester
    @digest_info[:digester].reset
  end

  # XML-friendly name
  def url
    @digest_info[:url]
  end

  def self.by_certificate(cert)
    case cert.signature_algorithm
      when 'GOST R 34.11-94 with GOST R 34.10-2001'
        self.new 'http://www.w3.org/2001/04/xmldsig-more#gostr34102001-gostr3411'
      else # most common 'sha1WithRSAEncryption' type included here
        self.new 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
    end
  end
end
