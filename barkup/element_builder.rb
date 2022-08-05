# typed: strict

module Barkup
  class ElementBuilder < BasicObject
    Element = ::Barkup::Element
    Builder = ::Barkup::Builder
    T = ::T

    extend T::Sig

    BooleanValue = ::T.type_alias { ::T.nilable(::T::Boolean) }
    Value = ::T.type_alias { ::T.nilable(::T.any(::String, ::Numeric, ::T::Boolean)) }
    EventHandler = ::T.type_alias { ::T.nilable(::T.proc.void) }

    sig {params(builder: Builder).void}
    def initialize(builder)
      @builder = builder
    end

    sig {params(klass: ::T.untyped).returns(::T::Boolean)}
    def is_a?(klass)
      ::Object.instance_method(:is_a?).bind(self).call(klass)
    end

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def a(*children, **attributes, &block)= tag!(:a, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def abbr(*children, **attributes, &block)= tag!(:abbr, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def address(*children, **attributes, &block)= tag!(:address, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def area(**attributes) = void!(:area, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def article(*children, **attributes, &block)= tag!(:article, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def aside(*children, **attributes, &block)= tag!(:aside, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def audio(*children, **attributes, &block)= tag!(:audio, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def b(*children, **attributes, &block)= tag!(:b, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def base(**attributes) = void!(:base, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def bdi(*children, **attributes, &block)= tag!(:bdi, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def bdo(*children, **attributes, &block)= tag!(:bdo, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def blockquote(*children, **attributes, &block)= tag!(:blockquote, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def body(*children, **attributes, &block)= tag!(:body, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def br(**attributes) = void!(:br, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def button(*children, **attributes, &block)= tag!(:button, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def canvas(*children, **attributes, &block)= tag!(:canvas, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def caption(*children, **attributes, &block)= tag!(:caption, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def cite(*children, **attributes, &block)= tag!(:cite, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def code(*children, **attributes, &block)= tag!(:code, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def col(**attributes) = void!(:col, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def colgroup(*children, **attributes, &block)= tag!(:colgroup, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def data(*children, **attributes, &block)= tag!(:data, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def datalist(*children, **attributes, &block)= tag!(:datalist, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def dd(*children, **attributes, &block)= tag!(:dd, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def del(*children, **attributes, &block)= tag!(:del, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def details(*children, **attributes, &block)= tag!(:details, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def dfn(*children, **attributes, &block)= tag!(:dfn, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def dialog(*children, **attributes, &block)= tag!(:dialog, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def div(*children, **attributes, &block)= tag!(:div, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def dl(*children, **attributes, &block)= tag!(:dl, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def dt(*children, **attributes, &block)= tag!(:dt, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def em(*children, **attributes, &block)= tag!(:em, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def embed(**attributes) = void!(:embed, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def fieldset(*children, **attributes, &block)= tag!(:fieldset, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def figcaption(*children, **attributes, &block)= tag!(:figcaption, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def figure(*children, **attributes, &block)= tag!(:figure, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def footer(*children, **attributes, &block)= tag!(:footer, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def form(*children, **attributes, &block)= tag!(:form, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def h1(*children, **attributes, &block)= tag!(:h1, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def h2(*children, **attributes, &block)= tag!(:h2, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def h3(*children, **attributes, &block)= tag!(:h3, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def h4(*children, **attributes, &block)= tag!(:h4, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def h5(*children, **attributes, &block)= tag!(:h5, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def h6(*children, **attributes, &block)= tag!(:h6, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def head(*children, **attributes, &block)= tag!(:head, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def header(*children, **attributes, &block)= tag!(:header, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def hgroup(*children, **attributes, &block)= tag!(:hgroup, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def hr(**attributes) = void!(:hr, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def html(*children, **attributes, &block)= tag!(:html, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def i(*children, **attributes, &block)= tag!(:i, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def iframe(*children, **attributes, &block)= tag!(:iframe, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def img(**attributes) = void!(:img, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def input(**attributes) = void!(:input, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def ins(*children, **attributes, &block)= tag!(:ins, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def kbd(*children, **attributes, &block)= tag!(:kbd, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def label(*children, **attributes, &block)= tag!(:label, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def legend(*children, **attributes, &block)= tag!(:legend, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def li(*children, **attributes, &block)= tag!(:li, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def link(**attributes) = void!(:link, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def main(*children, **attributes, &block)= tag!(:main, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def map(*children, **attributes, &block)= tag!(:map, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def mark(*children, **attributes, &block)= tag!(:mark, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def math(*children, **attributes, &block)= tag!(:math, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def menu(*children, **attributes, &block)= tag!(:menu, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def menuitem(**attributes) = void!(:menuitem, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def meta(**attributes) = void!(:meta, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def meter(*children, **attributes, &block)= tag!(:meter, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def nav(*children, **attributes, &block)= tag!(:nav, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def noscript(*children, **attributes, &block)= tag!(:noscript, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def object(*children, **attributes, &block)= tag!(:object, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def ol(*children, **attributes, &block)= tag!(:ol, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def optgroup(*children, **attributes, &block)= tag!(:optgroup, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def option(*children, **attributes, &block)= tag!(:option, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def output(*children, **attributes, &block)= tag!(:output, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def p(*children, **attributes, &block)= tag!(:p, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def param(**attributes) = void!(:param, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def picture(*children, **attributes, &block)= tag!(:picture, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def pre(*children, **attributes, &block)= tag!(:pre, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def progress(*children, **attributes, &block)= tag!(:progress, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def q(*children, **attributes, &block)= tag!(:q, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def rb(*children, **attributes, &block)= tag!(:rb, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def rp(*children, **attributes, &block)= tag!(:rp, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def rt(*children, **attributes, &block)= tag!(:rt, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def rtc(*children, **attributes, &block)= tag!(:rtc, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def ruby(*children, **attributes, &block)= tag!(:ruby, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def s(*children, **attributes, &block)= tag!(:s, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def samp(*children, **attributes, &block)= tag!(:samp, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def script(*children, **attributes, &block)= tag!(:script, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def section(*children, **attributes, &block)= tag!(:section, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def select(*children, **attributes, &block)= tag!(:select, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def slot(*children, **attributes, &block)= tag!(:slot, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def small(*children, **attributes, &block)= tag!(:small, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def source(**attributes) = void!(:source, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def span(*children, **attributes, &block)= tag!(:span, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def strong(*children, **attributes, &block)= tag!(:strong, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def style(*children, **attributes, &block)= tag!(:style, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def sub(*children, **attributes, &block)= tag!(:sub, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def summary(*children, **attributes, &block)= tag!(:summary, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def sup(*children, **attributes, &block)= tag!(:sup, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def svg(*children, **attributes, &block)= tag!(:svg, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def table(*children, **attributes, &block)= tag!(:table, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def tbody(*children, **attributes, &block)= tag!(:tbody, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def td(*children, **attributes, &block)= tag!(:td, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def template(*children, **attributes, &block)= tag!(:template, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def textarea(*children, **attributes, &block)= tag!(:textarea, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def tfoot(*children, **attributes, &block)= tag!(:tfoot, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def th(*children, **attributes, &block)= tag!(:th, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def thead(*children, **attributes, &block)= tag!(:thead, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def time(*children, **attributes, &block)= tag!(:time, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def title(*children, **attributes, &block)= tag!(:title, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def tr(*children, **attributes, &block)= tag!(:tr, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def track(**attributes) = void!(:track, **attributes)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def u(*children, **attributes, &block)= tag!(:u, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def ul(*children, **attributes, &block)= tag!(:ul, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def var(*children, **attributes, &block)= tag!(:var, children, **attributes, &block)

    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def video(*children, **attributes, &block)= tag!(:video, children, **attributes, &block)

    sig {params(attributes: ::T.untyped).void}
    def wbr(**attributes) = void!(:wbr, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def area(**attributes) = void!(:area, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def base(**attributes) = void!(:base, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def br(**attributes) = void!(:br, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def col(**attributes) = void!(:col, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def embed(**attributes) = void!(:embed, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def hr(**attributes) = void!(:hr, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def img(**attributes) = void!(:img, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def input(**attributes) = void!(:input, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def link(**attributes) = void!(:link, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def menuitem(**attributes) = void!(:menuitem, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def meta(**attributes) = void!(:meta, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def param(**attributes) = void!(:param, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def source(**attributes) = void!(:source, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def track(**attributes) = void!(:track, **attributes)

    sig {params(attributes: ::T.untyped).void}
    def wbr(**attributes) = void!(:wbr, **attributes)

    private

    sig {params(tag: ::Symbol, attributes: ::T.untyped).void}
    def void!(tag, **attributes)
      @builder << Element.new(tag, attributes.filter { _2 }, [])
    end

    sig {params(tag: ::Symbol, children: ::T::Array[::T.untyped], attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def tag!(tag, children, **attributes, &block)
      children = (children + (block ? @builder.capture(&block) : [])).map do
        Element.or_text(_1)
      end
      @builder << Element.new(tag, attributes.filter { _2 }, children)
    end
  end
end
