# frozen_string_literal: true

module Mayu
  module Klenod
    class Configuration
      DEFAULT_ENTRYPOINTS = %w[root.haml virtual:router].freeze
      DEFAULT_ASSET_BASE = "/.mayu/assets/"

      attr_reader :root,
        :mode

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

      def pages_dir(value = nil)
        return @pages_dir unless value

        @pages_dir = value
        @plugins =
          @plugins.map do |plugin|
            unless plugin.is_a?(::Klenod::Build::Plugins::RouterPlugin::Plugin)
              next plugin
            end

            ::Klenod::Build::Plugins::RouterPlugin.new(
              specifier: plugin.specifier,
              pages_dir: value,
              extensions: plugin.extensions,
              route_base_class: plugin.route_base_class
            )
          end
      end

      def entrypoint(value) = @entrypoints << value

      def entrypoints(*values) =
        values.empty? ? @entrypoints : @entrypoints.concat(values.flatten)

      def base(value = nil) = value ? @base = value : @base
      def assets_dir(value = nil) = value ? @assets_dir = value : @assets_dir
      def output(value = nil) = value ? @output = value : @output

      def plugins(value = nil, &block) =
        if value || block
          @plugins = (block ? block.call : value)
        else
          @plugins
        end

      def source_path = expand(source_dir)
      def assets_path = expand(assets_dir)
      def output_path = expand(output)

      def context(**overrides)
        ::Klenod::Build::Context.new(
          source_dir: source_path,
          mode:,
          base:,
          plugins:,
          namespace: Mayu::ModuleNamespace,
          **overrides
        )
      end

      def development_provider(**overrides)
        DevelopmentProvider.new(context(**overrides), assets_dir: assets_path)
      end

      def build(output: output_path, assets_dir: assets_path, **overrides, &reporter)
        context = context(**overrides)
        reporter&.call(:collecting_bundle, entrypoints:)
        bundle = context.graph.bundle(entrypoints:)
        reporter&.call(:bundle_collected, bundle:, assets: context.assets.values)

        if assets_dir
          reporter&.call(:materializing_assets, assets_dir:)
          context.write_assets(assets_dir) do |status, asset, path|
            reporter&.call(:asset_materialized, status:, asset:, path:)
          end
        else
          context.wait_for_assets
        end

        reporter&.call(:writing_bundle, output:)
        FileUtils.mkdir_p(File.dirname(output))
        File.binwrite(output, ::Klenod::Runtime::BundleFormat.dump(bundle))
        reporter&.call(:bundle_written, output:)
        bundle
      end

      def runtime_provider(bundle_path: output_path)
        RuntimeProvider.new(
          ::Klenod::Runtime.load_bundle(bundle_path, source_root: source_path),
          assets_dir: assets_path
        )
      end

      def route_manifest
        router_plugin.discover(source_dir: source_path)
      end

      private

      def expand(path)
        File.expand_path(path, root)
      end

      def router_plugin
        plugins.find do |plugin|
          plugin.is_a?(::Klenod::Build::Plugins::RouterPlugin::Plugin)
        end || raise("Klenod configuration does not include RouterPlugin")
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
          when ::Klenod::Build::Plugins::MarkdownPlugin::Plugin
            ::Klenod::Build::Plugins::MarkdownPlugin.new(
              component_base_class: "Mayu::Component::Base",
              factory: "Mayu::Runtime::H"
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
            ::Klenod::Test::Plugin.new,
            ::Klenod::Build::Plugins::RouterPlugin.new(
              pages_dir:,
              route_base_class: "Mayu::Route"
            ),
            ::Klenod::Build::Plugins::GoogleFontsPlugin.new(
              cache_path: File.join(root, ".mayu", "google_fonts")
            ),
            ::Klenod::Build::Plugins::CSSPlugin.new,
            ::Klenod::Build::Plugins::JavaScriptPlugin.new
          ]
      end
    end
  end
end
