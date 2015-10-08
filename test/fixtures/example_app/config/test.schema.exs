[
  import: [
    :fake_project
  ],
  mappings: [
    "test.foo": [
      doc: "Documentation for test.foo goes here.",
      to: "test.foo",
      datatype: :binary,
      default: "bar"
    ],
    "test.env": [
      doc: "The current execution environment",
      to: "test.env",
      datatype: :atom,
      default: :dev
    ],
    "test.debug.level": [
      doc: """
        Set the appropriate tracing options.
        Valid options are:
          - active:       tracing is enabled
          - active-debug: tracing is enabled, with debugging
          - passive:      tracing must be manually invoked
          - off:          tracing is disabled

        Defaults to off
        """,
      to: "test.debug_level",
      datatype: [
        enum: [
          :active,
          :"active-debug",
          :passive,
          :off
        ]
      ],
      default: :off
    ],
    "test.some_val": [
      doc: """
        Just a some val
      """,
      to: "test.some_val",
      datatype: :integer,
      default:  10
    ]
  ],
  transforms: [
    "test.debug_level": fn conf ->
      case Conform.Conf.get(conf, "test.debug_level") do
        [{_, :active}] ->
          {:on, []}
        [{_, :"active-debug"}] ->
          {:on, [:debug]}
        [{_, :passive}] ->
          {:on, [:passive]}
        [{_, :off}] ->
          {:off, []}
        [] ->
      end
    end,
    "test.some_val": fn conf ->
      case Conform.Conf.get(conf, "test.some_val") do
        [{_, x}] when is_integer(x) -> FakeProject.inc_some_val(x)
        [{_, x}] -> x
      end
    end
  ]
]
