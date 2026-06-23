export interface INotificationService {
  notifyRankingChanged(userIds: string[]): Promise<void>;
  sendPredictionsReminder(): Promise<void>;
  notifyAdminsOfPendingUser(user: { id: string; displayName: string; email: string }): Promise<void>;
}
