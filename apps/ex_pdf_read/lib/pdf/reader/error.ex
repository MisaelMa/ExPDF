defmodule Pdf.Reader.Error do
  @moduledoc """
  Exception raised by bang variants of `Pdf.Reader` functions.

  The `:reason` field carries the same atom or tagged tuple that the
  non-bang variant would have returned in `{:error, reason}`.

  Do not rescue this in production pipelines — use the non-bang forms
  and pattern-match on `{:error, reason}` instead.
  """

  defexception [:reason, :message]

  @impl true
  def exception(reason) do
    %__MODULE__{
      reason: reason,
      message: "Pdf.Reader error: #{inspect(reason)}"
    }
  end
end
