require 'openssl'

def gost_engine
  return @gost_engine  if @gost_engine
  OpenSSL::Engine.load
  @gost_engine = OpenSSL::Engine.by_id('gost')
  @gost_engine.set_default(0xFFFF)
  @gost_engine
end
