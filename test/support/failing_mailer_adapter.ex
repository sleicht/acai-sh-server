defmodule Acai.Support.FailingMailerAdapter do
  use Swoosh.Adapter

  def deliver(_email, _config), do: {:error, :smtp_down}
end
