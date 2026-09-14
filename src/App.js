import { useEffect, useState } from "react";
import "./App.css";
import { AmazonConnectApp } from "@amazon-connect/app";
import { AgentClient } from "@amazon-connect/contact";
import Cards from "@cloudscape-design/components/cards";
import Box from "@cloudscape-design/components/box";
import StatusIndicator from "@cloudscape-design/components/status-indicator";
import Select from "@cloudscape-design/components/select";
import Button from "@cloudscape-design/components/button";
import SpaceBetween from "@cloudscape-design/components/space-between";
import Alert from "@cloudscape-design/components/alert";
import {
  listRoutingProfiles,
  updateRoutingProfile
} from "./api";

const connectProvider = window.parent !== window
  ? AmazonConnectApp.init({
      onCreate: event => {
        console.info("Routing profile app initialized", {
          appInstanceId: event.context.appInstanceId
        });
      },
      onDestroy: () => {
        console.info("Routing profile app destroyed");
      }
    }).provider
  : null;

function RoutingProfileManager() {
  const [agentArn, setAgentArn] = useState("");
  const [agentRoutingProfile, setAgentRoutingProfile] = useState("");
  const [routingProfiles, setRoutingProfiles] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState(null);
  const [isLoadingProfiles, setIsLoadingProfiles] = useState(true);
  const [isUpdating, setIsUpdating] = useState(false);
  const [alertMessage, setAlertMessage] = useState(null);
  const [alertType, setAlertType] = useState("success");

  useEffect(() => {
    const agentClient = new AgentClient(connectProvider);

    async function fetchAgentData() {
      try {
        const [arn, routingProfile] = await Promise.all([
          agentClient.getARN(),
          agentClient.getRoutingProfile()
        ]);
        setAgentArn(arn);
        setAgentRoutingProfile(routingProfile.name);
      } catch (error) {
        console.error("Unable to read the current Connect agent", error);
        setAlertMessage("Unable to read the current Amazon Connect agent.");
        setAlertType("error");
      }
    }

    const handleRoutingProfileChanged = event => {
      if (event?.routingProfile?.name) {
        setAgentRoutingProfile(event.routingProfile.name);
      } else {
        void fetchAgentData();
      }
    };

    agentClient.onRoutingProfileChanged(handleRoutingProfileChanged);
    void fetchAgentData();

    return () => {
      agentClient.offRoutingProfileChanged(handleRoutingProfileChanged);
    };
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function fetchProfiles() {
      setIsLoadingProfiles(true);
      try {
        const data = await listRoutingProfiles();
        if (!cancelled) {
          setRoutingProfiles(data.routingProfiles || []);
        }
      } catch (error) {
        if (!cancelled) {
          setAlertMessage(error.message || "Unable to load routing profiles.");
          setAlertType("error");
        }
      } finally {
        if (!cancelled) {
          setIsLoadingProfiles(false);
        }
      }
    }

    void fetchProfiles();
    return () => {
      cancelled = true;
    };
  }, []);

  async function handleUpdateRoutingProfile() {
    if (!selectedProfile || !agentArn) return;

    setIsUpdating(true);
    setAlertMessage(null);

    try {
      const data = await updateRoutingProfile(agentArn, selectedProfile.value);
      const updatedName = data.routingProfile?.name || selectedProfile.label;
      setAgentRoutingProfile(updatedName);
      setSelectedProfile(null);
      setAlertMessage(`Routing profile updated to "${updatedName}".`);
      setAlertType("success");
    } catch (error) {
      setAlertMessage(error.message || "Unable to update the routing profile.");
      setAlertType("error");
    } finally {
      setIsUpdating(false);
    }
  }

  return (
    <main className="App">
      <section className="RoutingProfileCard" aria-label="Current routing profile">
        <Cards
          ariaLabels={{
            itemSelectionLabel: (_event, item) => `select ${item.name}`,
            selectionGroupLabel: "Item selection"
          }}
          cardDefinition={{
            header: item => (
              item.type === "N/A"
                ? <StatusIndicator type="pending">Loading</StatusIndicator>
                : <StatusIndicator>Available</StatusIndicator>
            ),
            sections: [
              {
                id: "description",
                header: "",
                content: item => <span className="EmphasizedText">{item.description}</span>
              },
              {
                id: "type",
                header: "",
                content: item => item.type
              }
            ]
          }}
          cardsPerRow={[{ cards: 1 }, { minWidth: 200, cards: 1 }]}
          items={[{
            name: "routingProfile",
            alt: "Agent Routing Profile",
            description: "Current agent routing profile",
            type: agentRoutingProfile || "N/A"
          }]}
          empty={<Box textAlign="center">No routing profile available</Box>}
        />
      </section>

      <section className="RoutingProfileSelector" aria-labelledby="change-profile-heading">
        <SpaceBetween size="m">
          <h3 id="change-profile-heading" className="SectionTitle">Change Routing Profile</h3>

          {alertMessage && (
            <Alert
              type={alertType}
              dismissible
              onDismiss={() => setAlertMessage(null)}
            >
              {alertMessage}
            </Alert>
          )}

          <Select
            selectedOption={selectedProfile}
            onChange={({ detail }) => setSelectedProfile(detail.selectedOption)}
            options={routingProfiles.map(profile => ({
              label: profile.name,
              value: profile.id
            }))}
            placeholder={isLoadingProfiles ? "Loading routing profiles" : "Select a routing profile"}
            empty="No routing profiles available"
            loadingText="Loading routing profiles"
            statusType={isLoadingProfiles ? "loading" : "finished"}
            disabled={isLoadingProfiles || isUpdating}
          />

          <Button
            variant="primary"
            onClick={handleUpdateRoutingProfile}
            loading={isUpdating}
            disabled={!selectedProfile || !agentArn || isUpdating || isLoadingProfiles}
          >
            Apply Routing Profile
          </Button>
        </SpaceBetween>
      </section>
    </main>
  );
}

function App() {
  if (!connectProvider) {
    return (
      <main className="ConfigurationError">
        <h2>Open this application from Amazon Connect</h2>
        <p>The routing profile manager is available inside the Connect Agent Workspace.</p>
      </main>
    );
  }

  return <RoutingProfileManager />;
}

export default App;
