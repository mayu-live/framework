# typed: strict
# DO NOT EDIT! THIS FILE IS GENERATED AUTOMATICALLY.
# If you want to change it, update `generate.rb` instead.
module Mayu
  module Markup
    module Generated
      module BuilderInterface
        extend T::Sig
        extend T::Helpers
        interface!
        sig do
          abstract
            .params(
              type: VDOM::Descriptor::ElementType,
              children: T::Array[VDOM::Descriptor::ChildType],
              props: T::Hash[Symbol, T.untyped],
              block: T.nilable(T.proc.void)
            )
            .returns(VDOM::Descriptor)
        end
        def create_element(type, children, props, &block)
        end
      end
      module DescriptorBuilders
        extend T::Sig
        include BuilderInterface
        BooleanValue = T.type_alias { T.nilable(T::Boolean) }
        Value =
          T.type_alias { T.nilable(T.any(::String, ::Numeric, T::Boolean)) }
        EventHandler = T.type_alias { T.nilable(T.proc.void) }
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def a(*children, **attributes, &block)
          tag!(:a, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def abbr(*children, **attributes, &block)
          tag!(:abbr, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def address(*children, **attributes, &block)
          tag!(:address, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def area(**attributes) = void!(:area, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def article(*children, **attributes, &block)
          tag!(:article, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def aside(*children, **attributes, &block)
          tag!(:aside, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def audio(*children, **attributes, &block)
          tag!(:audio, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def b(*children, **attributes, &block)
          tag!(:b, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def base(**attributes) = void!(:base, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def bdi(*children, **attributes, &block)
          tag!(:bdi, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def bdo(*children, **attributes, &block)
          tag!(:bdo, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def blockquote(*children, **attributes, &block)
          tag!(:blockquote, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def body(*children, **attributes, &block)
          tag!(:body, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def br(**attributes) = void!(:br, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def button(*children, **attributes, &block)
          tag!(:button, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def canvas(*children, **attributes, &block)
          tag!(:canvas, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def caption(*children, **attributes, &block)
          tag!(:caption, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def cite(*children, **attributes, &block)
          tag!(:cite, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def code(*children, **attributes, &block)
          tag!(:code, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def col(**attributes) = void!(:col, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def colgroup(*children, **attributes, &block)
          tag!(:colgroup, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def data(*children, **attributes, &block)
          tag!(:data, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def datalist(*children, **attributes, &block)
          tag!(:datalist, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def dd(*children, **attributes, &block)
          tag!(:dd, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def del(*children, **attributes, &block)
          tag!(:del, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def details(*children, **attributes, &block)
          tag!(:details, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def dfn(*children, **attributes, &block)
          tag!(:dfn, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def dialog(*children, **attributes, &block)
          tag!(:dialog, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def div(*children, **attributes, &block)
          tag!(:div, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def dl(*children, **attributes, &block)
          tag!(:dl, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def dt(*children, **attributes, &block)
          tag!(:dt, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def em(*children, **attributes, &block)
          tag!(:em, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def embed(**attributes) = void!(:embed, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def fieldset(*children, **attributes, &block)
          tag!(:fieldset, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def figcaption(*children, **attributes, &block)
          tag!(:figcaption, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def figure(*children, **attributes, &block)
          tag!(:figure, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def footer(*children, **attributes, &block)
          tag!(:footer, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def form(*children, **attributes, &block)
          tag!(:form, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def h1(*children, **attributes, &block)
          tag!(:h1, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def h2(*children, **attributes, &block)
          tag!(:h2, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def h3(*children, **attributes, &block)
          tag!(:h3, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def h4(*children, **attributes, &block)
          tag!(:h4, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def h5(*children, **attributes, &block)
          tag!(:h5, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def h6(*children, **attributes, &block)
          tag!(:h6, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def head(*children, **attributes, &block)
          tag!(:head, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def header(*children, **attributes, &block)
          tag!(:header, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def hgroup(*children, **attributes, &block)
          tag!(:hgroup, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def hr(**attributes) = void!(:hr, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def html(*children, **attributes, &block)
          tag!(:html, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def i(*children, **attributes, &block)
          tag!(:i, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def iframe(*children, **attributes, &block)
          tag!(:iframe, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def img(**attributes) = void!(:img, **attributes)
        sig { params(attributes: T.untyped).void }
        def input(**attributes) = void!(:input, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def ins(*children, **attributes, &block)
          tag!(:ins, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def kbd(*children, **attributes, &block)
          tag!(:kbd, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def label(*children, **attributes, &block)
          tag!(:label, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def legend(*children, **attributes, &block)
          tag!(:legend, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def li(*children, **attributes, &block)
          tag!(:li, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def link(**attributes) = void!(:link, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def main(*children, **attributes, &block)
          tag!(:main, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def map(*children, **attributes, &block)
          tag!(:map, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def mark(*children, **attributes, &block)
          tag!(:mark, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def math(*children, **attributes, &block)
          tag!(:math, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def menu(*children, **attributes, &block)
          tag!(:menu, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def menuitem(**attributes) = void!(:menuitem, **attributes)
        sig { params(attributes: T.untyped).void }
        def meta(**attributes) = void!(:meta, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def meter(*children, **attributes, &block)
          tag!(:meter, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def nav(*children, **attributes, &block)
          tag!(:nav, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def noscript(*children, **attributes, &block)
          tag!(:noscript, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def object(*children, **attributes, &block)
          tag!(:object, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def ol(*children, **attributes, &block)
          tag!(:ol, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def optgroup(*children, **attributes, &block)
          tag!(:optgroup, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def option(*children, **attributes, &block)
          tag!(:option, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def output(*children, **attributes, &block)
          tag!(:output, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def p(*children, **attributes, &block)
          tag!(:p, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def param(**attributes) = void!(:param, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def picture(*children, **attributes, &block)
          tag!(:picture, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def pre(*children, **attributes, &block)
          tag!(:pre, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def progress(*children, **attributes, &block)
          tag!(:progress, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def q(*children, **attributes, &block)
          tag!(:q, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def rb(*children, **attributes, &block)
          tag!(:rb, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def rp(*children, **attributes, &block)
          tag!(:rp, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def rt(*children, **attributes, &block)
          tag!(:rt, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def rtc(*children, **attributes, &block)
          tag!(:rtc, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def ruby(*children, **attributes, &block)
          tag!(:ruby, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def s(*children, **attributes, &block)
          tag!(:s, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def samp(*children, **attributes, &block)
          tag!(:samp, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def script(*children, **attributes, &block)
          tag!(:script, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def section(*children, **attributes, &block)
          tag!(:section, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def select(*children, **attributes, &block)
          tag!(:select, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def slot(*children, **attributes, &block)
          tag!(:slot, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def small(*children, **attributes, &block)
          tag!(:small, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def source(**attributes) = void!(:source, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def span(*children, **attributes, &block)
          tag!(:span, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def strong(*children, **attributes, &block)
          tag!(:strong, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def style(*children, **attributes, &block)
          tag!(:style, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def sub(*children, **attributes, &block)
          tag!(:sub, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def summary(*children, **attributes, &block)
          tag!(:summary, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def sup(*children, **attributes, &block)
          tag!(:sup, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def svg(*children, **attributes, &block)
          tag!(:svg, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def table(*children, **attributes, &block)
          tag!(:table, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def tbody(*children, **attributes, &block)
          tag!(:tbody, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def td(*children, **attributes, &block)
          tag!(:td, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def template(*children, **attributes, &block)
          tag!(:template, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def textarea(*children, **attributes, &block)
          tag!(:textarea, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def tfoot(*children, **attributes, &block)
          tag!(:tfoot, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def th(*children, **attributes, &block)
          tag!(:th, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def thead(*children, **attributes, &block)
          tag!(:thead, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def time(*children, **attributes, &block)
          tag!(:time, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def title(*children, **attributes, &block)
          tag!(:title, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def tr(*children, **attributes, &block)
          tag!(:tr, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def track(**attributes) = void!(:track, **attributes)
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def u(*children, **attributes, &block)
          tag!(:u, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def ul(*children, **attributes, &block)
          tag!(:ul, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def var(*children, **attributes, &block)
          tag!(:var, children, **attributes, &block)
        end
        sig do
          params(
            children: T.untyped,
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def video(*children, **attributes, &block)
          tag!(:video, children, **attributes, &block)
        end
        sig { params(attributes: T.untyped).void }
        def wbr(**attributes) = void!(:wbr, **attributes)
        sig { params(attributes: T.untyped).void }
        def area(**attributes) = void!(:area, **attributes)
        sig { params(attributes: T.untyped).void }
        def base(**attributes) = void!(:base, **attributes)
        sig { params(attributes: T.untyped).void }
        def br(**attributes) = void!(:br, **attributes)
        sig { params(attributes: T.untyped).void }
        def col(**attributes) = void!(:col, **attributes)
        sig { params(attributes: T.untyped).void }
        def embed(**attributes) = void!(:embed, **attributes)
        sig { params(attributes: T.untyped).void }
        def hr(**attributes) = void!(:hr, **attributes)
        sig { params(attributes: T.untyped).void }
        def img(**attributes) = void!(:img, **attributes)
        sig { params(attributes: T.untyped).void }
        def input(**attributes) = void!(:input, **attributes)
        sig { params(attributes: T.untyped).void }
        def link(**attributes) = void!(:link, **attributes)
        sig { params(attributes: T.untyped).void }
        def menuitem(**attributes) = void!(:menuitem, **attributes)
        sig { params(attributes: T.untyped).void }
        def meta(**attributes) = void!(:meta, **attributes)
        sig { params(attributes: T.untyped).void }
        def param(**attributes) = void!(:param, **attributes)
        sig { params(attributes: T.untyped).void }
        def source(**attributes) = void!(:source, **attributes)
        sig { params(attributes: T.untyped).void }
        def track(**attributes) = void!(:track, **attributes)
        sig { params(attributes: T.untyped).void }
        def wbr(**attributes) = void!(:wbr, **attributes)
        sig do
          override
            .params(
              type: VDOM::Descriptor::ElementType,
              children: T::Array[VDOM::Descriptor::ChildType],
              props: T::Hash[Symbol, T.untyped],
              block: T.nilable(T.proc.void)
            )
            .returns(VDOM::Descriptor)
        end
        def create_element(type, children, props, &block)
          ::Kernel.raise ::NotImplementedError
        end

        private

        sig do
          params(tag: ::Symbol, attributes: T.untyped).returns(VDOM::Descriptor)
        end
        def void!(tag, **attributes)
          create_element(tag, [], attributes)
        end
        sig do
          params(
            tag: ::Symbol,
            children: T::Array[T.untyped],
            attributes: T.untyped,
            block: T.nilable(T.proc.void)
          ).returns(VDOM::Descriptor)
        end
        def tag!(tag, children, **attributes, &block)
          create_element(tag, children, attributes, &block)
        end
      end
    end
  end
end
