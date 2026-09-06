# frozen_string_literal: true

module Mayu
  module Klenod
    class Configuration
      DEFAULT_ENTRYPOINTS = %w[root.haml virtual:router].freeze
      DEFAULT_ASSET_BASE = "/.mayu/assets/"

      attr_reader :root,
                  :mode,
                  :source_dir,
                  :pages_dir,
                  :entrypoints,
                  :base,
                  :assets_dir,
                  :output,
                  :plugins

      def initialize(
        root:,
        mode: :development,
        source_dir: "app",
        pages_dir: "pages",
        entrypoints: DEFAULT_ENTRYPOINTS,
        base: DEFAULT_ASSET_BASE,
        assets_dir: ".assets",
        output: ".mayu/klenod.bundle",
        plugins: nil
      )
        @root = File.expand_path(root)
        @mode = mode.to_sym
        @source_dir = source_dir
        @pages_dir = pages_dir
        @entrypoints = Array(entrypoints).dup
        @base = base
        @assets_dir = assets_dir
        @output = output
        @plugins = plugins || default_plugins
      end

      def self.load(root:, mode: :development, **overrides)
        configuration = new(root:, mode:, **overrides)
        path =
          File.join(
            configuration.root,
            ::Klenod::Build::ConfigLoader::CONFIG_FILE
          )
        if File.file?(path)
          configuration.instance_eval(File.read(path), path, 1)
        end
        configuration
      end

      def source_dir(value = nil) = value ? @source_dir = value : @source_dir
      def pages_dir(value = nil) = value ? @pages_dir = value : @pages_dir
      def entrypoint(value) = @entrypoints << value
      def entrypoints(*values) =
        values.empty? ? @entrypoints : @entrypoints.concat(values.flatten)
      def base(value = nil) = value ? @base = value : @base
      def assets_dir(value = nil) = value ? @assets_dir = value : @assets_dir
      def output(value = nil) = value ? @output = value : @output
      def plugins(value = nil, &block) =
        value || block ? @plugins = (block ? block.call : value) : @plugins

      def source_path = expand(source_dir)
      def assets_path = expand(assets_dir)
      def output_path = expand(output)

      def context(**overrides)
        ::Klenod::Build::Context.new(
          source_dir: source_path,
          mode:,
          base:,
          plugins:,
          **overrides
        )
      end

      def development_provider(**overrides)
        DevelopmentProvider.new(context(**overrides), assets_dir: assets_path)
      end

      def build(**overrides)
        context(**overrides).build(
          entrypoints:,
          output: output_path,
          assets_dir: assets_path
        )
      end

      def runtime_provider(bundle_path: output_path)
        RuntimeProvider.new(
          ::Klenod::Runtime.load_bundle(bundle_path, source_root: source_path),
          assets_dir: assets_path
        )
      end

      private

      def expand(path)
        File.expand_path(path, root)
      end

      def default_plugins
        ::Klenod::Build::Context.default_plugins.map do |plugin|
          case plugin
          when ::Klenod::Build::Plugins::HamlPlugin::Plugin
            ::Klenod::Build::Plugins::HamlPlugin.new(
              component_base_class: "Mayu::Component::Base",
              factory: "Mayu::Runtime::H",
              event_handler: "Mayu::Runtime::H",
              variables: {
                global: "@__props",
                class: "@__context",
                instance: "@__state"
              }
            )
          when ::Klenod::Build::Plugins::ImagePlugin::Plugin
            ::Klenod::Build::Plugins::ImagePlugin.new(
              placeholder: {
                width: 16,
                format: "webp",
                quality: 80
              }
            )
          else
            plugin
          end
        end +
          [
            ::Klenod::Build::Plugins::RouterPlugin.new(
              pages_dir:,
              route_base_class: "Mayu::Route"
            ),
            ::Klenod::Build::Plugins::CSSPlugin.new,
            ::Klenod::Build::Plugins::JavaScriptPlugin.new
          ]
      end
    end
  end
end
