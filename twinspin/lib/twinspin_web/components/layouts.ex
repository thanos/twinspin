defmodule TwinspinWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TwinspinWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950">
      <!-- Navbar -->
      <nav class="border-b border-gray-800 bg-gray-900">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <!-- Brand Logo -->
            <div class="flex items-center">
              <a href="/" class="flex items-center gap-2">
                <span class="text-2xl font-bold text-cyan-400 font-mono">
                  {Twinspin.Settings.get_brand_name()}
                  <span class="text-2xl font-bold text-white font-mono">
                    · Database Reconciliation
                  </span>
                </span>
              </a>
            </div>
            
    <!-- Navigation Links -->
            <div class="flex items-center gap-1">
              <.nav_link href="/" text="Connections" />
              <.nav_link href="/settings" text="Settings" icon="hero-cog-6-tooth" />
            </div>
          </div>
        </div>
      </nav>
      
    <!-- Main Content -->
      <main>
        {render_slot(@inner_block)}
      </main>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :text, :string, required: true
  attr :icon, :string, default: nil

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-2 rounded-lg px-3 py-2 font-mono text-sm text-gray-300 transition-colors hover:bg-gray-800 hover:text-cyan-400"
    >
      <.icon :if={@icon} name={@icon} class="size-5" />
      {@text}
    </a>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
