# typed: strict

module Mayu
  module VDOM
    class Descriptor
    end
  end
  module Markup
    class Builder
    end
    class DescriptorBuilder < BasicObject
      Descriptor = ::Mayu::VDOM::Descriptor
      Builder = ::Mayu::Markup::Builder
      T = ::T
      extend T::Sig
      BooleanValue = ::T.type_alias { ::T.nilable(::T::Boolean) }
      Value =
        ::T.type_alias do
          ::T.nilable(::T.any(::String, ::Numeric, ::T::Boolean))
        end
      EventHandler = ::T.type_alias { ::T.nilable(::T.proc.void) }
      sig { params(builder: Builder).void }
      def initialize(builder)
        @builder = builder
      end
      sig { params(klass: ::T.untyped).returns(::T::Boolean) }
      def is_a?(klass)
        ::Object.instance_method(:is_a?).bind(self).call(klass)
      end
      module TagClosers
        class BaseTagCloser < BasicObject
          extend ::T::Sig
          sig { params(klass: ::T.untyped).returns(::T::Boolean) }
          def is_a?(klass)
            ::Object.instance_method(:is_a?).bind(self).call(klass)
          end
        end
        class A < BaseTagCloser
          sig { void }
          def a = nil
        end
        class Abbr < BaseTagCloser
          sig { void }
          def abbr = nil
        end
        class Address < BaseTagCloser
          sig { void }
          def address = nil
        end
        class Area < BaseTagCloser
          sig { void }
          def area = nil
        end
        class Article < BaseTagCloser
          sig { void }
          def article = nil
        end
        class Aside < BaseTagCloser
          sig { void }
          def aside = nil
        end
        class Audio < BaseTagCloser
          sig { void }
          def audio = nil
        end
        class B < BaseTagCloser
          sig { void }
          def b = nil
        end
        class Base < BaseTagCloser
          sig { void }
          def base = nil
        end
        class Bdi < BaseTagCloser
          sig { void }
          def bdi = nil
        end
        class Bdo < BaseTagCloser
          sig { void }
          def bdo = nil
        end
        class Blockquote < BaseTagCloser
          sig { void }
          def blockquote = nil
        end
        class Body < BaseTagCloser
          sig { void }
          def body = nil
        end
        class Br < BaseTagCloser
          sig { void }
          def br = nil
        end
        class Button < BaseTagCloser
          sig { void }
          def button = nil
        end
        class Canvas < BaseTagCloser
          sig { void }
          def canvas = nil
        end
        class Caption < BaseTagCloser
          sig { void }
          def caption = nil
        end
        class Cite < BaseTagCloser
          sig { void }
          def cite = nil
        end
        class Code < BaseTagCloser
          sig { void }
          def code = nil
        end
        class Col < BaseTagCloser
          sig { void }
          def col = nil
        end
        class Colgroup < BaseTagCloser
          sig { void }
          def colgroup = nil
        end
        class Data < BaseTagCloser
          sig { void }
          def data = nil
        end
        class Datalist < BaseTagCloser
          sig { void }
          def datalist = nil
        end
        class Dd < BaseTagCloser
          sig { void }
          def dd = nil
        end
        class Del < BaseTagCloser
          sig { void }
          def del = nil
        end
        class Details < BaseTagCloser
          sig { void }
          def details = nil
        end
        class Dfn < BaseTagCloser
          sig { void }
          def dfn = nil
        end
        class Dialog < BaseTagCloser
          sig { void }
          def dialog = nil
        end
        class Div < BaseTagCloser
          sig { void }
          def div = nil
        end
        class Dl < BaseTagCloser
          sig { void }
          def dl = nil
        end
        class Dt < BaseTagCloser
          sig { void }
          def dt = nil
        end
        class Em < BaseTagCloser
          sig { void }
          def em = nil
        end
        class Embed < BaseTagCloser
          sig { void }
          def embed = nil
        end
        class Fieldset < BaseTagCloser
          sig { void }
          def fieldset = nil
        end
        class Figcaption < BaseTagCloser
          sig { void }
          def figcaption = nil
        end
        class Figure < BaseTagCloser
          sig { void }
          def figure = nil
        end
        class Footer < BaseTagCloser
          sig { void }
          def footer = nil
        end
        class Form < BaseTagCloser
          sig { void }
          def form = nil
        end
        class H1 < BaseTagCloser
          sig { void }
          def h1 = nil
        end
        class H2 < BaseTagCloser
          sig { void }
          def h2 = nil
        end
        class H3 < BaseTagCloser
          sig { void }
          def h3 = nil
        end
        class H4 < BaseTagCloser
          sig { void }
          def h4 = nil
        end
        class H5 < BaseTagCloser
          sig { void }
          def h5 = nil
        end
        class H6 < BaseTagCloser
          sig { void }
          def h6 = nil
        end
        class Head < BaseTagCloser
          sig { void }
          def head = nil
        end
        class Header < BaseTagCloser
          sig { void }
          def header = nil
        end
        class Hgroup < BaseTagCloser
          sig { void }
          def hgroup = nil
        end
        class Hr < BaseTagCloser
          sig { void }
          def hr = nil
        end
        class Html < BaseTagCloser
          sig { void }
          def html = nil
        end
        class I < BaseTagCloser
          sig { void }
          def i = nil
        end
        class Iframe < BaseTagCloser
          sig { void }
          def iframe = nil
        end
        class Img < BaseTagCloser
          sig { void }
          def img = nil
        end
        class Input < BaseTagCloser
          sig { void }
          def input = nil
        end
        class Ins < BaseTagCloser
          sig { void }
          def ins = nil
        end
        class Kbd < BaseTagCloser
          sig { void }
          def kbd = nil
        end
        class Label < BaseTagCloser
          sig { void }
          def label = nil
        end
        class Legend < BaseTagCloser
          sig { void }
          def legend = nil
        end
        class Li < BaseTagCloser
          sig { void }
          def li = nil
        end
        class Link < BaseTagCloser
          sig { void }
          def link = nil
        end
        class Main < BaseTagCloser
          sig { void }
          def main = nil
        end
        class Map < BaseTagCloser
          sig { void }
          def map = nil
        end
        class Mark < BaseTagCloser
          sig { void }
          def mark = nil
        end
        class Math < BaseTagCloser
          sig { void }
          def math = nil
        end
        class Menu < BaseTagCloser
          sig { void }
          def menu = nil
        end
        class Menuitem < BaseTagCloser
          sig { void }
          def menuitem = nil
        end
        class Meta < BaseTagCloser
          sig { void }
          def meta = nil
        end
        class Meter < BaseTagCloser
          sig { void }
          def meter = nil
        end
        class Nav < BaseTagCloser
          sig { void }
          def nav = nil
        end
        class Noscript < BaseTagCloser
          sig { void }
          def noscript = nil
        end
        class Object < BaseTagCloser
          sig { void }
          def object = nil
        end
        class Ol < BaseTagCloser
          sig { void }
          def ol = nil
        end
        class Optgroup < BaseTagCloser
          sig { void }
          def optgroup = nil
        end
        class Option < BaseTagCloser
          sig { void }
          def option = nil
        end
        class Output < BaseTagCloser
          sig { void }
          def output = nil
        end
        class P < BaseTagCloser
          sig { void }
          def p = nil
        end
        class Param < BaseTagCloser
          sig { void }
          def param = nil
        end
        class Picture < BaseTagCloser
          sig { void }
          def picture = nil
        end
        class Pre < BaseTagCloser
          sig { void }
          def pre = nil
        end
        class Progress < BaseTagCloser
          sig { void }
          def progress = nil
        end
        class Q < BaseTagCloser
          sig { void }
          def q = nil
        end
        class Rb < BaseTagCloser
          sig { void }
          def rb = nil
        end
        class Rp < BaseTagCloser
          sig { void }
          def rp = nil
        end
        class Rt < BaseTagCloser
          sig { void }
          def rt = nil
        end
        class Rtc < BaseTagCloser
          sig { void }
          def rtc = nil
        end
        class Ruby < BaseTagCloser
          sig { void }
          def ruby = nil
        end
        class S < BaseTagCloser
          sig { void }
          def s = nil
        end
        class Samp < BaseTagCloser
          sig { void }
          def samp = nil
        end
        class Script < BaseTagCloser
          sig { void }
          def script = nil
        end
        class Section < BaseTagCloser
          sig { void }
          def section = nil
        end
        class Select < BaseTagCloser
          sig { void }
          def select = nil
        end
        class Slot < BaseTagCloser
          sig { void }
          def slot = nil
        end
        class Small < BaseTagCloser
          sig { void }
          def small = nil
        end
        class Source < BaseTagCloser
          sig { void }
          def source = nil
        end
        class Span < BaseTagCloser
          sig { void }
          def span = nil
        end
        class Strong < BaseTagCloser
          sig { void }
          def strong = nil
        end
        class Style < BaseTagCloser
          sig { void }
          def style = nil
        end
        class Sub < BaseTagCloser
          sig { void }
          def sub = nil
        end
        class Summary < BaseTagCloser
          sig { void }
          def summary = nil
        end
        class Sup < BaseTagCloser
          sig { void }
          def sup = nil
        end
        class Svg < BaseTagCloser
          sig { void }
          def svg = nil
        end
        class Table < BaseTagCloser
          sig { void }
          def table = nil
        end
        class Tbody < BaseTagCloser
          sig { void }
          def tbody = nil
        end
        class Td < BaseTagCloser
          sig { void }
          def td = nil
        end
        class Template < BaseTagCloser
          sig { void }
          def template = nil
        end
        class Textarea < BaseTagCloser
          sig { void }
          def textarea = nil
        end
        class Tfoot < BaseTagCloser
          sig { void }
          def tfoot = nil
        end
        class Th < BaseTagCloser
          sig { void }
          def th = nil
        end
        class Thead < BaseTagCloser
          sig { void }
          def thead = nil
        end
        class Time < BaseTagCloser
          sig { void }
          def time = nil
        end
        class Title < BaseTagCloser
          sig { void }
          def title = nil
        end
        class Tr < BaseTagCloser
          sig { void }
          def tr = nil
        end
        class Track < BaseTagCloser
          sig { void }
          def track = nil
        end
        class U < BaseTagCloser
          sig { void }
          def u = nil
        end
        class Ul < BaseTagCloser
          sig { void }
          def ul = nil
        end
        class Var < BaseTagCloser
          sig { void }
          def var = nil
        end
        class Video < BaseTagCloser
          sig { void }
          def video = nil
        end
        class Wbr < BaseTagCloser
          sig { void }
          def wbr = nil
        end
        class Area < BaseTagCloser
          sig { void }
          def area = nil
        end
        class Base < BaseTagCloser
          sig { void }
          def base = nil
        end
        class Br < BaseTagCloser
          sig { void }
          def br = nil
        end
        class Col < BaseTagCloser
          sig { void }
          def col = nil
        end
        class Embed < BaseTagCloser
          sig { void }
          def embed = nil
        end
        class Hr < BaseTagCloser
          sig { void }
          def hr = nil
        end
        class Img < BaseTagCloser
          sig { void }
          def img = nil
        end
        class Input < BaseTagCloser
          sig { void }
          def input = nil
        end
        class Link < BaseTagCloser
          sig { void }
          def link = nil
        end
        class Menuitem < BaseTagCloser
          sig { void }
          def menuitem = nil
        end
        class Meta < BaseTagCloser
          sig { void }
          def meta = nil
        end
        class Param < BaseTagCloser
          sig { void }
          def param = nil
        end
        class Source < BaseTagCloser
          sig { void }
          def source = nil
        end
        class Track < BaseTagCloser
          sig { void }
          def track = nil
        end
        class Wbr < BaseTagCloser
          sig { void }
          def wbr = nil
        end
      end
      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::A)
      end
      def a(*children, **attributes, &block)
        tag!(:a, children, **attributes, &block)
        TagClosers::A.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Abbr)
      end
      def abbr(*children, **attributes, &block)
        tag!(:abbr, children, **attributes, &block)
        TagClosers::Abbr.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Address)
      end
      def address(*children, **attributes, &block)
        tag!(:address, children, **attributes, &block)
        TagClosers::Address.new
      end

      sig { params(attributes: ::T.untyped).void }
      def area(**attributes) = void!(:area, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Article)
      end
      def article(*children, **attributes, &block)
        tag!(:article, children, **attributes, &block)
        TagClosers::Article.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Aside)
      end
      def aside(*children, **attributes, &block)
        tag!(:aside, children, **attributes, &block)
        TagClosers::Aside.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Audio)
      end
      def audio(*children, **attributes, &block)
        tag!(:audio, children, **attributes, &block)
        TagClosers::Audio.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::B)
      end
      def b(*children, **attributes, &block)
        tag!(:b, children, **attributes, &block)
        TagClosers::B.new
      end

      sig { params(attributes: ::T.untyped).void }
      def base(**attributes) = void!(:base, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Bdi)
      end
      def bdi(*children, **attributes, &block)
        tag!(:bdi, children, **attributes, &block)
        TagClosers::Bdi.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Bdo)
      end
      def bdo(*children, **attributes, &block)
        tag!(:bdo, children, **attributes, &block)
        TagClosers::Bdo.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Blockquote)
      end
      def blockquote(*children, **attributes, &block)
        tag!(:blockquote, children, **attributes, &block)
        TagClosers::Blockquote.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Body)
      end
      def body(*children, **attributes, &block)
        tag!(:body, children, **attributes, &block)
        TagClosers::Body.new
      end

      sig { params(attributes: ::T.untyped).void }
      def br(**attributes) = void!(:br, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Button)
      end
      def button(*children, **attributes, &block)
        tag!(:button, children, **attributes, &block)
        TagClosers::Button.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Canvas)
      end
      def canvas(*children, **attributes, &block)
        tag!(:canvas, children, **attributes, &block)
        TagClosers::Canvas.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Caption)
      end
      def caption(*children, **attributes, &block)
        tag!(:caption, children, **attributes, &block)
        TagClosers::Caption.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Cite)
      end
      def cite(*children, **attributes, &block)
        tag!(:cite, children, **attributes, &block)
        TagClosers::Cite.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Code)
      end
      def code(*children, **attributes, &block)
        tag!(:code, children, **attributes, &block)
        TagClosers::Code.new
      end

      sig { params(attributes: ::T.untyped).void }
      def col(**attributes) = void!(:col, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Colgroup)
      end
      def colgroup(*children, **attributes, &block)
        tag!(:colgroup, children, **attributes, &block)
        TagClosers::Colgroup.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Data)
      end
      def data(*children, **attributes, &block)
        tag!(:data, children, **attributes, &block)
        TagClosers::Data.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Datalist)
      end
      def datalist(*children, **attributes, &block)
        tag!(:datalist, children, **attributes, &block)
        TagClosers::Datalist.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Dd)
      end
      def dd(*children, **attributes, &block)
        tag!(:dd, children, **attributes, &block)
        TagClosers::Dd.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Del)
      end
      def del(*children, **attributes, &block)
        tag!(:del, children, **attributes, &block)
        TagClosers::Del.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Details)
      end
      def details(*children, **attributes, &block)
        tag!(:details, children, **attributes, &block)
        TagClosers::Details.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Dfn)
      end
      def dfn(*children, **attributes, &block)
        tag!(:dfn, children, **attributes, &block)
        TagClosers::Dfn.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Dialog)
      end
      def dialog(*children, **attributes, &block)
        tag!(:dialog, children, **attributes, &block)
        TagClosers::Dialog.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Div)
      end
      def div(*children, **attributes, &block)
        tag!(:div, children, **attributes, &block)
        TagClosers::Div.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Dl)
      end
      def dl(*children, **attributes, &block)
        tag!(:dl, children, **attributes, &block)
        TagClosers::Dl.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Dt)
      end
      def dt(*children, **attributes, &block)
        tag!(:dt, children, **attributes, &block)
        TagClosers::Dt.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Em)
      end
      def em(*children, **attributes, &block)
        tag!(:em, children, **attributes, &block)
        TagClosers::Em.new
      end

      sig { params(attributes: ::T.untyped).void }
      def embed(**attributes) = void!(:embed, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Fieldset)
      end
      def fieldset(*children, **attributes, &block)
        tag!(:fieldset, children, **attributes, &block)
        TagClosers::Fieldset.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Figcaption)
      end
      def figcaption(*children, **attributes, &block)
        tag!(:figcaption, children, **attributes, &block)
        TagClosers::Figcaption.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Figure)
      end
      def figure(*children, **attributes, &block)
        tag!(:figure, children, **attributes, &block)
        TagClosers::Figure.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Footer)
      end
      def footer(*children, **attributes, &block)
        tag!(:footer, children, **attributes, &block)
        TagClosers::Footer.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Form)
      end
      def form(*children, **attributes, &block)
        tag!(:form, children, **attributes, &block)
        TagClosers::Form.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::H1)
      end
      def h1(*children, **attributes, &block)
        tag!(:h1, children, **attributes, &block)
        TagClosers::H1.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::H2)
      end
      def h2(*children, **attributes, &block)
        tag!(:h2, children, **attributes, &block)
        TagClosers::H2.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::H3)
      end
      def h3(*children, **attributes, &block)
        tag!(:h3, children, **attributes, &block)
        TagClosers::H3.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::H4)
      end
      def h4(*children, **attributes, &block)
        tag!(:h4, children, **attributes, &block)
        TagClosers::H4.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::H5)
      end
      def h5(*children, **attributes, &block)
        tag!(:h5, children, **attributes, &block)
        TagClosers::H5.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::H6)
      end
      def h6(*children, **attributes, &block)
        tag!(:h6, children, **attributes, &block)
        TagClosers::H6.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Head)
      end
      def head(*children, **attributes, &block)
        tag!(:head, children, **attributes, &block)
        TagClosers::Head.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Header)
      end
      def header(*children, **attributes, &block)
        tag!(:header, children, **attributes, &block)
        TagClosers::Header.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Hgroup)
      end
      def hgroup(*children, **attributes, &block)
        tag!(:hgroup, children, **attributes, &block)
        TagClosers::Hgroup.new
      end

      sig { params(attributes: ::T.untyped).void }
      def hr(**attributes) = void!(:hr, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Html)
      end
      def html(*children, **attributes, &block)
        tag!(:html, children, **attributes, &block)
        TagClosers::Html.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::I)
      end
      def i(*children, **attributes, &block)
        tag!(:i, children, **attributes, &block)
        TagClosers::I.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Iframe)
      end
      def iframe(*children, **attributes, &block)
        tag!(:iframe, children, **attributes, &block)
        TagClosers::Iframe.new
      end

      sig { params(attributes: ::T.untyped).void }
      def img(**attributes) = void!(:img, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def input(**attributes) = void!(:input, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Ins)
      end
      def ins(*children, **attributes, &block)
        tag!(:ins, children, **attributes, &block)
        TagClosers::Ins.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Kbd)
      end
      def kbd(*children, **attributes, &block)
        tag!(:kbd, children, **attributes, &block)
        TagClosers::Kbd.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Label)
      end
      def label(*children, **attributes, &block)
        tag!(:label, children, **attributes, &block)
        TagClosers::Label.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Legend)
      end
      def legend(*children, **attributes, &block)
        tag!(:legend, children, **attributes, &block)
        TagClosers::Legend.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Li)
      end
      def li(*children, **attributes, &block)
        tag!(:li, children, **attributes, &block)
        TagClosers::Li.new
      end

      sig { params(attributes: ::T.untyped).void }
      def link(**attributes) = void!(:link, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Main)
      end
      def main(*children, **attributes, &block)
        tag!(:main, children, **attributes, &block)
        TagClosers::Main.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Map)
      end
      def map(*children, **attributes, &block)
        tag!(:map, children, **attributes, &block)
        TagClosers::Map.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Mark)
      end
      def mark(*children, **attributes, &block)
        tag!(:mark, children, **attributes, &block)
        TagClosers::Mark.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Math)
      end
      def math(*children, **attributes, &block)
        tag!(:math, children, **attributes, &block)
        TagClosers::Math.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Menu)
      end
      def menu(*children, **attributes, &block)
        tag!(:menu, children, **attributes, &block)
        TagClosers::Menu.new
      end

      sig { params(attributes: ::T.untyped).void }
      def menuitem(**attributes) = void!(:menuitem, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def meta(**attributes) = void!(:meta, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Meter)
      end
      def meter(*children, **attributes, &block)
        tag!(:meter, children, **attributes, &block)
        TagClosers::Meter.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Nav)
      end
      def nav(*children, **attributes, &block)
        tag!(:nav, children, **attributes, &block)
        TagClosers::Nav.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Noscript)
      end
      def noscript(*children, **attributes, &block)
        tag!(:noscript, children, **attributes, &block)
        TagClosers::Noscript.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Object)
      end
      def object(*children, **attributes, &block)
        tag!(:object, children, **attributes, &block)
        TagClosers::Object.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Ol)
      end
      def ol(*children, **attributes, &block)
        tag!(:ol, children, **attributes, &block)
        TagClosers::Ol.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Optgroup)
      end
      def optgroup(*children, **attributes, &block)
        tag!(:optgroup, children, **attributes, &block)
        TagClosers::Optgroup.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Option)
      end
      def option(*children, **attributes, &block)
        tag!(:option, children, **attributes, &block)
        TagClosers::Option.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Output)
      end
      def output(*children, **attributes, &block)
        tag!(:output, children, **attributes, &block)
        TagClosers::Output.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::P)
      end
      def p(*children, **attributes, &block)
        tag!(:p, children, **attributes, &block)
        TagClosers::P.new
      end

      sig { params(attributes: ::T.untyped).void }
      def param(**attributes) = void!(:param, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Picture)
      end
      def picture(*children, **attributes, &block)
        tag!(:picture, children, **attributes, &block)
        TagClosers::Picture.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Pre)
      end
      def pre(*children, **attributes, &block)
        tag!(:pre, children, **attributes, &block)
        TagClosers::Pre.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Progress)
      end
      def progress(*children, **attributes, &block)
        tag!(:progress, children, **attributes, &block)
        TagClosers::Progress.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Q)
      end
      def q(*children, **attributes, &block)
        tag!(:q, children, **attributes, &block)
        TagClosers::Q.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Rb)
      end
      def rb(*children, **attributes, &block)
        tag!(:rb, children, **attributes, &block)
        TagClosers::Rb.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Rp)
      end
      def rp(*children, **attributes, &block)
        tag!(:rp, children, **attributes, &block)
        TagClosers::Rp.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Rt)
      end
      def rt(*children, **attributes, &block)
        tag!(:rt, children, **attributes, &block)
        TagClosers::Rt.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Rtc)
      end
      def rtc(*children, **attributes, &block)
        tag!(:rtc, children, **attributes, &block)
        TagClosers::Rtc.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Ruby)
      end
      def ruby(*children, **attributes, &block)
        tag!(:ruby, children, **attributes, &block)
        TagClosers::Ruby.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::S)
      end
      def s(*children, **attributes, &block)
        tag!(:s, children, **attributes, &block)
        TagClosers::S.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Samp)
      end
      def samp(*children, **attributes, &block)
        tag!(:samp, children, **attributes, &block)
        TagClosers::Samp.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Script)
      end
      def script(*children, **attributes, &block)
        tag!(:script, children, **attributes, &block)
        TagClosers::Script.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Section)
      end
      def section(*children, **attributes, &block)
        tag!(:section, children, **attributes, &block)
        TagClosers::Section.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Select)
      end
      def select(*children, **attributes, &block)
        tag!(:select, children, **attributes, &block)
        TagClosers::Select.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Slot)
      end
      def slot(*children, **attributes, &block)
        tag!(:slot, children, **attributes, &block)
        TagClosers::Slot.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Small)
      end
      def small(*children, **attributes, &block)
        tag!(:small, children, **attributes, &block)
        TagClosers::Small.new
      end

      sig { params(attributes: ::T.untyped).void }
      def source(**attributes) = void!(:source, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Span)
      end
      def span(*children, **attributes, &block)
        tag!(:span, children, **attributes, &block)
        TagClosers::Span.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Strong)
      end
      def strong(*children, **attributes, &block)
        tag!(:strong, children, **attributes, &block)
        TagClosers::Strong.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Style)
      end
      def style(*children, **attributes, &block)
        tag!(:style, children, **attributes, &block)
        TagClosers::Style.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Sub)
      end
      def sub(*children, **attributes, &block)
        tag!(:sub, children, **attributes, &block)
        TagClosers::Sub.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Summary)
      end
      def summary(*children, **attributes, &block)
        tag!(:summary, children, **attributes, &block)
        TagClosers::Summary.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Sup)
      end
      def sup(*children, **attributes, &block)
        tag!(:sup, children, **attributes, &block)
        TagClosers::Sup.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Svg)
      end
      def svg(*children, **attributes, &block)
        tag!(:svg, children, **attributes, &block)
        TagClosers::Svg.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Table)
      end
      def table(*children, **attributes, &block)
        tag!(:table, children, **attributes, &block)
        TagClosers::Table.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Tbody)
      end
      def tbody(*children, **attributes, &block)
        tag!(:tbody, children, **attributes, &block)
        TagClosers::Tbody.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Td)
      end
      def td(*children, **attributes, &block)
        tag!(:td, children, **attributes, &block)
        TagClosers::Td.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Template)
      end
      def template(*children, **attributes, &block)
        tag!(:template, children, **attributes, &block)
        TagClosers::Template.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Textarea)
      end
      def textarea(*children, **attributes, &block)
        tag!(:textarea, children, **attributes, &block)
        TagClosers::Textarea.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Tfoot)
      end
      def tfoot(*children, **attributes, &block)
        tag!(:tfoot, children, **attributes, &block)
        TagClosers::Tfoot.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Th)
      end
      def th(*children, **attributes, &block)
        tag!(:th, children, **attributes, &block)
        TagClosers::Th.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Thead)
      end
      def thead(*children, **attributes, &block)
        tag!(:thead, children, **attributes, &block)
        TagClosers::Thead.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Time)
      end
      def time(*children, **attributes, &block)
        tag!(:time, children, **attributes, &block)
        TagClosers::Time.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Title)
      end
      def title(*children, **attributes, &block)
        tag!(:title, children, **attributes, &block)
        TagClosers::Title.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Tr)
      end
      def tr(*children, **attributes, &block)
        tag!(:tr, children, **attributes, &block)
        TagClosers::Tr.new
      end

      sig { params(attributes: ::T.untyped).void }
      def track(**attributes) = void!(:track, **attributes)

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::U)
      end
      def u(*children, **attributes, &block)
        tag!(:u, children, **attributes, &block)
        TagClosers::U.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Ul)
      end
      def ul(*children, **attributes, &block)
        tag!(:ul, children, **attributes, &block)
        TagClosers::Ul.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Var)
      end
      def var(*children, **attributes, &block)
        tag!(:var, children, **attributes, &block)
        TagClosers::Var.new
      end

      sig do
        params(
          children: ::T.untyped,
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).returns(TagClosers::Video)
      end
      def video(*children, **attributes, &block)
        tag!(:video, children, **attributes, &block)
        TagClosers::Video.new
      end

      sig { params(attributes: ::T.untyped).void }
      def wbr(**attributes) = void!(:wbr, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def area(**attributes) = void!(:area, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def base(**attributes) = void!(:base, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def br(**attributes) = void!(:br, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def col(**attributes) = void!(:col, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def embed(**attributes) = void!(:embed, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def hr(**attributes) = void!(:hr, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def img(**attributes) = void!(:img, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def input(**attributes) = void!(:input, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def link(**attributes) = void!(:link, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def menuitem(**attributes) = void!(:menuitem, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def meta(**attributes) = void!(:meta, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def param(**attributes) = void!(:param, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def source(**attributes) = void!(:source, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def track(**attributes) = void!(:track, **attributes)

      sig { params(attributes: ::T.untyped).void }
      def wbr(**attributes) = void!(:wbr, **attributes)

      private

      sig { params(tag: ::Symbol, attributes: ::T.untyped).void }
      def void!(tag, **attributes)
        @builder << Descriptor.new(tag, attributes.filter { _2 }, [])
      end
      sig do
        params(
          tag: ::Symbol,
          children: ::T::Array[::T.untyped],
          attributes: ::T.untyped,
          block: ::T.nilable(::T.proc.bind(Builder).void)
        ).void
      end
      def tag!(tag, children, **attributes, &block)
        children =
          (children + (block ? @builder.capture(&block) : [])).map do
            Descriptor.or_text(_1)
          end
        @builder << Descriptor.new(tag, attributes.filter { _2 }, children)
      end
    end
  end
end
