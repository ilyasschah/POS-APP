using FluentValidation;
using MediatR;
using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Commands.TimeClockCommands.BatchSync;

public class BatchSyncTimeClockCommand : IRequest<BatchSyncTimeClockResponse>
{
    public BatchSyncTimeClockRequest Request { get; }
    public int CompanyId { get; }

    public BatchSyncTimeClockCommand(BatchSyncTimeClockRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class Validator : AbstractValidator<BatchSyncTimeClockCommand>
    {
        public Validator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0);
            RuleFor(x => x.Request.Entries)
                .NotNull()
                .Must(e => e.Count > 0).WithMessage("Batch must contain at least one entry.");
            RuleForEach(x => x.Request.Entries)
                .ChildRules(e =>
                {
                    e.RuleFor(x => x.LocalId).NotEmpty();
                    e.RuleFor(x => x.UserId).GreaterThan(0);
                });
        }
    }

    public class Handler : IRequestHandler<BatchSyncTimeClockCommand, BatchSyncTimeClockResponse>
    {
        private readonly TimeClockRepository _repository;
        private readonly ILogger<Handler> _logger;

        public Handler(TimeClockRepository repository, ILogger<Handler> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public async Task<BatchSyncTimeClockResponse> Handle(
            BatchSyncTimeClockCommand command,
            CancellationToken cancellationToken)
        {
            var response = new BatchSyncTimeClockResponse();

            // No outer transaction — one bad entry must not roll back the rest.
            foreach (var dto in command.Request.Entries)
            {
                try
                {
                    TimeClockEntry? existing = dto.ServerId.HasValue && dto.ServerId > 0
                        ? await _repository.GetByIdAsync(dto.ServerId.Value)
                        : null;

                    if (existing is not null)
                    {
                        existing.SyncFrom(dto.ClockInTime, dto.ClockOutTime);
                        await _repository.UpdateAsync(existing);
                        response.UpdatedCount++;
                        response.Results.Add(new SyncedTimeClockResult
                        {
                            LocalId = dto.LocalId,
                            ServerId = existing.Id,
                        });
                    }
                    else
                    {
                        var entry = TimeClockEntry.Create(
                            command.CompanyId,
                            dto.UserId,
                            dto.ClockInTime);

                        if (dto.ClockOutTime.HasValue)
                            entry.ClockOut(dto.ClockOutTime.Value);

                        await _repository.AddAsync(entry);
                        response.InsertedCount++;
                        response.Results.Add(new SyncedTimeClockResult
                        {
                            LocalId = dto.LocalId,
                            ServerId = entry.Id,
                        });
                    }

                    response.SyncedCount++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "BatchSync failed for time clock entry [LocalId={LocalId}]", dto.LocalId);
                    response.Errors.Add($"Entry [{dto.LocalId}]: {ex.Message}");
                }
            }

            return response;
        }
    }
}
