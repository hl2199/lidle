class Lidle < Formula
  desc "Give your MacBook an awake window before it sleeps on lid-close/clamshell"
  homepage "https://github.com/hl2199/lidle"
  url "https://github.com/hl2199/lidle/archive/refs/tags/v1.0.0.tar.gz"
  # Fill in after tagging the release:
  #   curl -sL https://github.com/hl2199/lidle/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  def install
    bin.install "lidle"
  end

  def caveats
    <<~EOS
      lidle needs a one-time privileged setup that Homebrew can't do for you
      (it installs a system-wide background service). After installing — and
      again after each `brew upgrade lidle` — run:

        sudo lidle install

      Add the menu bar item when prompted, or later with:

        sudo lidle menu-setup

      To stop and fully remove the service:

        sudo lidle uninstall
    EOS
  end

  test do
    assert_match "lidle #{version}", shell_output("#{bin}/lidle version")
  end
end
