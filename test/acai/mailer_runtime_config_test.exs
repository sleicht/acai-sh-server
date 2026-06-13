defmodule Acai.MailerRuntimeConfigTest do
  use ExUnit.Case, async: false

  @runtime_env ~w(
    DATABASE_URL
    ECTO_IPV6
    POOL_SIZE
    SECRET_KEY_BASE
    SMTP_AUTH
    SMTP_CACERTFILE
    SMTP_NO_MX_LOOKUPS
    SMTP_PASSWORD
    SMTP_PORT
    SMTP_RELAY
    SMTP_RETRIES
    SMTP_SSL
    SMTP_TLS
    SMTP_USERNAME
    START_SERVER
  )

  setup do
    previous_env = Map.new(@runtime_env, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(previous_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)
  end

  test "email-delivery.SMTP.1 email-delivery.SMTP.2: production mailer uses smtp environment settings" do
    put_prod_env(%{
      "SMTP_AUTH" => "if_available",
      "SMTP_CACERTFILE" => "/custom/ca-bundle.crt",
      "SMTP_NO_MX_LOOKUPS" => "true",
      "SMTP_PASSWORD" => "smtp-pass",
      "SMTP_PORT" => "2525",
      "SMTP_RELAY" => "smtp.example.com",
      "SMTP_RETRIES" => "5",
      "SMTP_SSL" => "true",
      "SMTP_TLS" => "never",
      "SMTP_USERNAME" => "smtp-user"
    })

    mailer_config = prod_mailer_config()

    assert mailer_config[:adapter] == Swoosh.Adapters.SMTP
    assert mailer_config[:relay] == "smtp.example.com"
    assert mailer_config[:username] == "smtp-user"
    assert mailer_config[:password] == "smtp-pass"
    assert mailer_config[:port] == 2525
    assert mailer_config[:ssl] == true
    assert mailer_config[:tls] == :never

    assert mailer_config[:tls_options] == [
             verify: :verify_peer,
             cacertfile: "/custom/ca-bundle.crt",
             depth: 4,
             server_name_indication: ~c"smtp.example.com"
           ]

    assert mailer_config[:auth] == :if_available
    assert mailer_config[:retries] == 5
    assert mailer_config[:no_mx_lookups] == true
  end

  test "email-delivery.SMTP.2-1: production mailer defaults to direct relay routing with sni" do
    put_prod_env(%{"SMTP_RELAY" => "mail.example.com"})

    mailer_config = prod_mailer_config()

    assert mailer_config[:relay] == "mail.example.com"

    assert mailer_config[:tls_options] == [
             verify: :verify_peer,
             cacertfile: "/etc/ssl/certs/ca-certificates.crt",
             depth: 4,
             server_name_indication: ~c"mail.example.com"
           ]

    assert mailer_config[:no_mx_lookups] == true
  end

  test "email-delivery.SMTP.3: deployment examples expose smtp variables instead of mailgun" do
    docker_compose = File.read!("infra/docker-compose.yml")
    env_example = File.read!("infra/.env.example")

    for file <- [docker_compose, env_example] do
      assert file =~ "SMTP_RELAY"
      assert file =~ "SMTP_USERNAME"
      assert file =~ "SMTP_PASSWORD"
      assert file =~ "SMTP_PORT"
      refute file =~ "MAILGUN"
    end
  end

  defp prod_mailer_config do
    config =
      "config/runtime.exs"
      |> Path.expand()
      |> Config.Reader.read_imports!(env: :prod)

    config
    |> Keyword.fetch!(:acai)
    |> Keyword.fetch!(Acai.Mailer)
  end

  defp put_prod_env(overrides) do
    Enum.each(@runtime_env, &System.delete_env/1)

    base_env = %{
      "DATABASE_URL" => "ecto://postgres:postgres@localhost/acai_prod",
      "SECRET_KEY_BASE" => String.duplicate("a", 64),
      "START_SERVER" => "true"
    }

    base_env
    |> Map.merge(overrides)
    |> Enum.each(fn {key, value} -> System.put_env(key, value) end)
  end
end
