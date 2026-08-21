using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class StartingCashService
    {
        private readonly StartingCashRepository _repository;
        private readonly PosSessionRepository _sessions;

        public StartingCashService(
            StartingCashRepository repository, PosSessionRepository sessions)
        {
            _repository = repository;
            _sessions = sessions;
        }

        public async Task<StartingCash> Create(CreateStartingCashRequest req)
        {
            if (req.Amount < 0)
                throw new InvalidOperationException("Amount cannot be negative.");

            if (!await _repository.UserExistsAsync(req.UserId))
                throw new InvalidOperationException($"User with Id '{req.UserId}' does not exist.");

            var entity = StartingCash.Create(
                userId: req.UserId,
                amount: req.Amount,
                description: string.IsNullOrWhiteSpace(req.Description) ? null : req.Description.Trim(),
                startingCashType: req.StartingCashType ?? 0,
                zReportNumber: req.ZReportNumber,
                dateCreated: req.DateCreated ?? DateTime.UtcNow
            );
            entity.CompanyId = req.CompanyId;

            // Bind to the session that was trading. Resolved from the client's
            // localId because a movement recorded offline belongs to a session
            // that may not have reached the server yet. Unresolvable → left
            // null rather than refused: a cash movement is a record of money
            // that already moved, and losing it is worse than losing its link.
            if (!string.IsNullOrWhiteSpace(req.SessionLocalId))
            {
                var session = await _sessions.ResolveSessionAsync(
                    req.CompanyId, req.SessionLocalId);
                entity.SessionId = session?.Id;
            }

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateStartingCashRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"StartingCash with ID '{id}' not found.");

            if (req.Amount < 0)
                throw new InvalidOperationException("Amount cannot be negative.");

            if (!await _repository.UserExistsAsync(req.UserId))
                throw new InvalidOperationException($"User with Id '{req.UserId}' does not exist.");

            entity.Update(
                userId: req.UserId,
                amount: req.Amount,
                description: string.IsNullOrWhiteSpace(req.Description) ? null : req.Description.Trim(),
                startingCashType: req.StartingCashType,
                zReportNumber: req.ZReportNumber,
                dateCreated: req.DateCreated
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
