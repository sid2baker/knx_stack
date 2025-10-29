defmodule KNXStackTest do
  use ExUnit.Case
  doctest KNXStack

  test "has version" do
    assert KNXStack.version() == "0.1.0"
  end
end
