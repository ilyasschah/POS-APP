using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.StartingCashCommands.Add
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
                var entity = await _service.Create(command.Request);
                return MapperStartingCash.MapToStartingCashDto(entity);
            }
        }

        public class AddStartingCashCommandValidator : AbstractValidator<AddStartingCashCommand>
        {
            public AddStartingCashCommandValidator()
            {
                RuleFor(x => x.Request.UserId).GreaterThan(0);
                RuleFor(x => x.Request.Amount).GreaterThanOrEqualTo(0);
            }
        }
    }
}
