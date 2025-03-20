defmodule Mix.Tasks.Thumbhash.Install do
  @moduledoc """
   Run mix thumbhash.install this will copy the js hooks to the assets/hooks directory.
  """

  def run([args]) do
    js_source = __MODULE__.download_js()

    js_target =
      Path.join(
        File.cwd!(),
        ["/assets/", "/vendor/thumbhash.js"]
      )

    source =
      Path.join(
        Application.app_dir(:thumbhash, "/assets"),
        "/js/hooks/thumbhash.js"
      )

    target =
      Path.join(
        File.cwd!(),
        ["/assets/", "/js/hooks/thumbhash.js"]
      )

    Mix.Generator.copy_file(js_source, js_target)
    Mix.Generator.copy_file(source, target)
  end

  def download_js() do
    src = "https://raw.githubusercontent.com/evanw/thumbhash/refs/heads/main/js/thumbhash.js"
    System.cmd("wget", [src, "-O", "/tmp/thumbhash.js"])
    "/tmp/thumbhash.js"
  end
end
