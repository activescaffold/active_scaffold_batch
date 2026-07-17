module ActiveScaffoldBatch
  module Version
    MAJOR = 3
    MINOR = 8
    PATCH = '0.pre' # release 3.8.0 when AS 4.4.0 is supported, update dependency in gemspec

    STRING = [MAJOR, MINOR, PATCH].compact.join('.')
  end
end
