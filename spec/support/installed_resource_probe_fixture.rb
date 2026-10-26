# frozen_string_literal: true

require_relative "../../scripts/support/installed_source_contract_probe"

module InstalledResourceProbeFixture
  Loader = Struct.new(:failure, :handle, :freed) do
    include Emfsvg::InstalledSourceContractProbe::NativeResourceProbe

    private

    def slot
      Fiddle::Pointer[[handle].pack("J")]
    end

    def pointer(output)
      output[0, 8].unpack1("J")
    end

    def checked(_name, _bytes, _size, _limits, _output)
      raise failure if failure
    end

    def invoke(name, document)
      freed << [name, document]
    end
  end
end
