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
  translations: [
    "test.debug.level": fn _mapping, val ->
      case(val) do
        :active ->
          {:on, []}
        :"active-debug" ->
          {:on, [:debug]}
        :passive ->
          {:on, [:passive]}
        :off ->
          {:off, []}
      end
    end,
    "test.some_val": fn _mapping, val ->
      FakeProject.inc_some_val(val)
    end
  ]
]
