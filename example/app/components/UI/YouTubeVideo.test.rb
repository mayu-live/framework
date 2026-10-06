# frozen_string_literal: true

YouTubeVideo = import("./YouTubeVideo.haml")

def iframe_src(**props)
  render(YouTubeVideo, video_id: "AsSyElPknts", **props).get_by_css("iframe")["src"]
end

def test_src_without_options_has_no_query
  assert_equal("https://www.youtube.com/embed/AsSyElPknts", iframe_src)
end

def test_loop_sets_the_video_as_its_own_playlist
  assert_equal(
    "https://www.youtube.com/embed/AsSyElPknts?loop=1&playlist=AsSyElPknts",
    iframe_src(loop: true)
  )
end

def test_loop_with_a_list_keeps_the_list
  assert_equal(
    "https://www.youtube.com/embed/AsSyElPknts?list=PL123&loop=1",
    iframe_src(loop: true, list: "PL123")
  )
end

def test_video_id_is_escaped
  assert_equal("https://www.youtube.com/embed/a%2Fb%3Fc", iframe_src(video_id: "a/b?c"))
end
