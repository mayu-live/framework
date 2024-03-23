module Mayu
  Image = Data.define(:path, :format, :size, :digest) do
    def public_path
      Kernel.format(
        "/.mayu/assets/%s.%s?%s",
        File.basename(path, ".*"),
        format,
        digest
      )
    end
  end
end
