(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`Cloud`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Server`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Client Capability Propagation (Self-Describing Session IDs)*)
(* The cloud transport is stateless: initialize, tools/list, and tools/call each arrive as separate
   HTTP requests with no server-side session store. A client capability that must survive across
   requests (in v1 this is only MCP-Apps UI support, gated on $clientSupportsUI) therefore cannot
   live in kernel state between requests. Instead it is packed into the Mcp-Session-Id header itself:
   the server encodes the negotiated capabilities into the session ID at `initialize`, the client
   echoes that ID on every later request, and the server decodes it back to re-establish the
   capability flags per request -- the way a signed token carries claims. The ID is a versioned,
   colon-delimited string "version:base36bitfield:uuid" where the bitfield packs the tracked feature
   flags and the trailing UUID keeps every ID unique and opaque. See Specs/CloudDeployment.md. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Configuration*)

(* Ordered list of tracked capability flags. Each flag maps to a fixed bit position, so this order
   must not change without bumping $idVersion -- a shifted bit position would make a session ID
   minted by an older deployment decode to the wrong features. Only "MCPApps" is acted on in v1; the
   rest reserve stable bit positions for features that need a server->client channel to act on. *)
$trackedFeatureList = { "MCPApps", "Roots", "FormElicitation", "URLElicitation" };

(* Session-ID format version. Bump whenever $trackedFeatureList changes in a way that shifts bit
   positions, so that IDs minted by an older deployment decode to no features (fail-closed) rather
   than misfiring on the new bit layout. *)
$idVersion = "1";

(* <| "MCPApps" -> 0, "Roots" -> 1, "FormElicitation" -> 2, "URLElicitation" -> 3 |> *)
$trackedFeatureIDs = First /@ PositionIndex[ $trackedFeatureList ] - 1;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSessionIDFromFeatureList*)
(* Encode a client feature list into a self-describing session ID "version:base36bitfield:uuid".
   Intersecting with $trackedFeatureList first drops any untracked feature before it can reach the
   bitfield (so an unknown feature never contributes a bit); the empty set totals to 0 and encodes
   as "1:0:...". *)
makeSessionIDFromFeatureList // beginDefinition;

makeSessionIDFromFeatureList[ clientFeatures_List ] :=
    StringRiffle[
        {
            $idVersion,
            IntegerString[
                Total[ 2 ^ Lookup[ $trackedFeatureIDs, Intersection[ clientFeatures, $trackedFeatureList ] ] ],
                36
            ],
            CreateUUID[ ]
        },
        ":"
    ];

makeSessionIDFromFeatureList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFeaturesFromSessionID*)
(* Decode a session ID back into its feature list. Only the current "1" version shape decodes to
   features; any other version or a malformed ID falls through to {} (fail-closed), so a client
   replaying a session ID minted by an older deployment simply gets no features -- turning MCP-Apps
   off rather than misfiring. *)
getFeaturesFromSessionID // beginDefinition;

getFeaturesFromSessionID[ sessionID_String ] :=
    getFeaturesFromSessionID @ StringSplit[ sessionID, ":" ];

getFeaturesFromSessionID[ { "1", featureString_String, _String } ] :=
    Pick[
        $trackedFeatureList,
        Reverse @ IntegerDigits[ FromDigits[ featureString, 36 ], 2, Length @ $trackedFeatureList ],
        1
    ];

getFeaturesFromSessionID[ _ ] := { };

getFeaturesFromSessionID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
