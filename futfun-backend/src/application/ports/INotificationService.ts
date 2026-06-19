export interface INotificationService {
  notifyRankingChanged(userIds: string[]): Promise<void>;
  sendPredictionsReminder(): Promise<void>;
}
