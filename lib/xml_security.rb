# The contents of this file are subject to the terms
# of the Common Development and Distribution License
# (the License). You may not use this file except in
# compliance with the License.
#
# You can obtain a copy of the License at
# https://opensso.dev.java.net/public/CDDLv1.0.html or
# opensso/legal/CDDLv1.0.txt
# See the License for the specific language governing
# permission and limitations under the License.
#
# When distributing Covered Code, include this CDDL
# Header Notice in each file and include the License file
# at opensso/legal/CDDLv1.0.txt.
# If applicable, add the following below the CDDL Header,
# with the fields enclosed by brackets [] replaced by
# your own identifying information:
# "Portions Copyrighted [year] [name of copyright owner]"
#
# $Id: xml_sec.rb,v 1.6 2007/10/24 00:28:41 todddd Exp $
#
# Copyright 2007 Sun Microsystems Inc. All Rights Reserved
# Portions Copyrighted 2007 Todd W Saxton.

require 'rubygems'
require "rexml/document"
require "rexml/xpath"
require "openssl"
require "xmlcanonicalizer"
require "digest/sha1"
require 'rsa_ext.rb'
require_relative 'signature_algorithm'
require_relative 'digest_algorithm'

module XMLSecurity

  def self.sign_query(request_params, settings)
    algorithm = SignatureAlgorithm.by_certificate(settings.sp_public_cert)
    request_params = request_params + "&" + "SigAlg=" + CGI.escape(algorithm.url)
    request_params << "&" + "Signature=" + CGI.escape(Base64.encode64(settings.private_key.sign(algorithm.digester, request_params)))
    request_params
  end

  def self.return_to(uri_string)
    "&" + "returnTo=" + CGI.escape(uri_string)
  end

  def self.validate_request(saml_request, sing_alg, signature, settings)
    # building query string
    query = 'SAMLRequest' + '=' + CGI.escape(saml_request)
    query = query +  "&" + "SigAlg=" + CGI.escape(sing_alg)
    signature = Base64.decode64(signature)
    settings.idp_public_cert.public_key.verify(SignatureAlgorithm.new(sing_alg).digester, signature, query)
  end

  def self.decode_request(request)
	  request = Base64.decode64(request)
  	zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
  	buf = zstream.inflate(request)
  	zstream.finish
  	zstream.close
  	buf
  end

  def self.request_params(query,request_str = "SAMLRequest")
    deflated_request  = Zlib::Deflate.deflate(query, 9)[2..-5]
    request_str + "=" + CGI.escape(Base64.encode64(deflated_request))
  end

  class SignedDocument < REXML::Document

    def validate (idp_cert_fingerprint, logger = nil, private_key = nil)
      # get cert from response
      base64_cert             = self.elements["//ds:X509Certificate"].text
      cert_text               = Base64.decode64(base64_cert)
      cert                    = OpenSSL::X509::Certificate.new(cert_text)

      # check cert matches registered idp cert
      fingerprint             = Digest::SHA1.hexdigest(cert.to_der)
      valid_flag              = fingerprint == idp_cert_fingerprint.gsub(":", "").downcase

      return valid_flag if !valid_flag

      if validate_doc(base64_cert, logger)
        return true
       elsif private_key
         return decode(private_key)
      else
        return false
      end
    end

    def validate_doc(cert, logger)
      # validate references

      # remove signature node
      sig_element = REXML::XPath.first(self, "//ds:Signature", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"})
      return false unless sig_element
      sig_element.remove

#      #check digests
      REXML::XPath.each(sig_element, "//ds:Reference", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"}) do | ref |

        uri                   = ref.attributes.get_attribute("URI").value
        hashed_element        = REXML::XPath.first(self, "//[@ID='#{uri[1,uri.size]}']")
        canoner               = XML::Util::XmlCanonicalizer.new(false, true)
        canon_hashed_element  = canoner.canonicalize(hashed_element)
        algorithm             = REXML::XPath.first(ref, "//ds:DigestMethod", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"}).attributes.get_attribute("Algorithm").value
        hash                  = Base64.encode64(DigestAlgorithm.new(algorithm).digest(canon_hashed_element)).chomp
        digest_value          = REXML::XPath.first(ref, "//ds:DigestValue", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"}).text

        valid_flag            = hash == digest_value

        return valid_flag if !valid_flag
      end

      # verify signature
      canoner                 = XML::Util::XmlCanonicalizer.new(false, true)
      signed_info_element     = REXML::XPath.first(sig_element, "//ds:SignedInfo", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"})
      canon_string            = canoner.canonicalize(signed_info_element)

      signature_algorithm     = REXML::XPath.first(signed_info_element, "//ds:SignatureMethod", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"}).attributes.get_attribute("Algorithm").value
      signature_digester      = SignatureAlgorithm.new(signature_algorithm).digester
      base64_signature        = REXML::XPath.first(sig_element, "//ds:SignatureValue", {"ds"=>"http://www.w3.org/2000/09/xmldsig#"}).text
      signature               = Base64.decode64(base64_signature)

      # get certificate object
      valid_flag              = cert.public_key.verify(signature_digester, signature, canon_string)

      return valid_flag
    end
    
    def decode private_key
      # This is the public key which encrypted the first CipherValue
      certs = REXML::XPath.match(self, '//ds:X509Certificate', 'ds' => "http://www.w3.org/2000/09/xmldsig#") # array two elements    dcert   = REXML::XPath.first(self, '//ds:X509Certificate')#, 'ds' => "http://www.w3.org/2000/09/xmldsig#")

      #Find the certificate for the private key
      cert = certs.select{|c| OpenSSL::X509::Certificate.new(Base64.decode64(c.text)).check_private_key(private_key)}
      unless cert.empty?
        cert = cert[0]
      else
        return false
      end
      c1, c2 = REXML::XPath.match(self, '//xenc:CipherValue', 'xenc' => 'http://www.w3.org/2001/04/xmlenc#')

      # Generate the key used for the cipher below via the RSA::OAEP algo
      rsak      = RSA::Key.new private_key.n, private_key.d
      v1s       = Base64.decode64(c1.text)

      begin
        cipherkey = RSA::OAEP.decode rsak, v1s
      rescue RSA::OAEP::DecodeError
        return false
      end

      # The aes-128-cbc cipher has a 128 bit initialization vector (16 bytes)
      # and this is the first 16 bytes of the raw string.
      bytes  = Base64.decode64(c2.text).bytes.to_a
      iv     = bytes[0...16].pack('c*')
      others = bytes[16..-1].pack('c*')

      cipher = OpenSSL::Cipher.new('aes-128-cbc')
      cipher.decrypt
      cipher.iv  = iv
      cipher.key = cipherkey

      out = cipher.update(others)

      # The encrypted string's length might not be a multiple of the block
      # length of aes-128-cbc (16), so add in another block and then trim
      # off the padding. More info about padding is available at
      # http://www.w3.org/TR/2002/REC-xmlenc-core-20021210/Overview.html in
      # Section 5.2
      out << cipher.update("\x00" * 16)
      padding = out.bytes.to_a.last
      self.class.new(out[0..-(padding + 1)])
    end
  end
end
