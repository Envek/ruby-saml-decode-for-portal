module Onelogin::Saml
  class Settings
    attr_accessor :assertion_consumer_service_url, :issuer, :sp_name_qualifier
    attr_accessor :idp_sso_target_url, :idp_slo_target_url, :idp_cert_fingerprint, :name_identifier_format, :return_to_url
    attr_reader   :private_key, :idp_public_cert, :sp_public_cert

    def private_key=(private_key_path)
      @private_key =  OpenSSL::PKey.read(File.read(private_key_path))
    end

    def idp_public_cert=(idp_public_cert_path)
      @idp_public_cert = OpenSSL::X509::Certificate.new(File.read(idp_public_cert_path))
    end

    def sp_public_cert=(sp_public_cert_path)
      @sp_public_cert = OpenSSL::X509::Certificate.new(File.read(sp_public_cert_path))
    end

  end
end
