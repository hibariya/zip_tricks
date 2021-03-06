# frozen_string_literal: true

# Stashes a block given by the Rack webserver when calling each() on a body, and calls
# that block every time it is written to using :<< (shovel). Poses as an IO for rubyzip.

class ZipTricks::BlockWrite
  # The block is the block given to each() of the Rack body, or other block you want
  # to receive the string chunks written by the zip compressor.
  def initialize(&block)
    @block = block
  end

  # Make sure those methods raise outright
  %i[seek pos= to_s].each do |m|
    define_method(m) do |*_args|
      raise "#{m} not supported - this IO adapter is non-rewindable"
    end
  end

  # Every time this object gets written to, call the Rack body each() block
  # with the bytes given instead.
  def <<(buf)
    # Zero-size output has a special meaning  when using chunked encoding
    return if buf.nil? || buf.bytesize.zero?

    # Ensure we ALWAYS write in binary encoding.
    encoded =
      if buf.encoding != Encoding::BINARY
        # If we got a frozen string we can't force_encoding on it
        begin
          buf.force_encoding(Encoding::BINARY)
        rescue
          buf.dup.force_encoding(Encoding::BINARY)
        end
      else
        buf
      end

    @block.call(encoded)
    self
  end
end
