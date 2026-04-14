export interface RoomProps {
  index: number;
  active: boolean;
  spacing: number;
}

export interface RoomDefinition {
  name: string;
  component: React.ComponentType<RoomProps>;
}