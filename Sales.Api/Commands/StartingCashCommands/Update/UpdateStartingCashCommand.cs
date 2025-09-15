using FluentValidation;
using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.StartingCashCommands.Update
{
    public class UpdateStartingCashCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateStartingCashRequest Request { get; }

        public UpdateStartingCashCommand(int id, UpdateStartingCashRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateStartingCashCommandHandler : IRequestHandler<UpdateStartingCashCommand, bool>
        {
            private readonly StartingCashService _service;

            public UpdateStartingCashCommandHandler(StartingCashService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateStartingCashCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateStartingCashCommandValidator : AbstractValidator<UpdateStartingCashCommand>
        {
            public UpdateStartingCashCommandValidator()
            {
                RuleFor(x => x.Id).GreaterThan(0);
                RuleFor(x => x.Request.UserId).GreaterThan(0);
                RuleFor(x => x.Request.Amount).GreaterThanOrEqualTo(0);
            }
        }
    }
}
