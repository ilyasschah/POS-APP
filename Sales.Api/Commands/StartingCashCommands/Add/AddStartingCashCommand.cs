using FluentValidation;
using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Sales.Api.Commands.StartingCashCommands.Add
{
    public class AddStartingCashCommand : IRequest<StartingCashDto>
    {
        public CreateStartingCashRequest Request { get; }

        public AddStartingCashCommand(CreateStartingCashRequest request)
        {
            Request = request;
        }

        public class AddStartingCashCommandHandler : IRequestHandler<AddStartingCashCommand, StartingCashDto>
        {
            private readonly StartingCashService _service;

            public AddStartingCashCommandHandler(StartingCashService service)
            {
                _service = service;
            }

            public async Task<StartingCashDto> Handle(AddStartingCashCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperStartingCash.MapToStartingCashDto(newEntity);
            }
        }

        public class AddStartingCashCommandValidator : AbstractValidator<AddStartingCashCommand>
        {
            public AddStartingCashCommandValidator()
            {
                RuleFor(c => c.Request.UserId).GreaterThan(0);
                RuleFor(c => c.Request.Amount).GreaterThanOrEqualTo(0);
                RuleFor(c => c.Request.ZReportNumber).GreaterThan(0);
            }
        }
    }
}