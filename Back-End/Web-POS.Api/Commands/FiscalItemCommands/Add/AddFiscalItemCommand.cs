using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Services;

namespace Api.Commands.FiscalItemCommands.Add
{
    public class AddFiscalItemCommand : IRequest<FiscalItemDto>
    {
        public CreateFiscalItemRequest Request { get; }

        public AddFiscalItemCommand(CreateFiscalItemRequest request)
        {
            Request = request;
        }

        public class AddFiscalItemCommandHandler : IRequestHandler<AddFiscalItemCommand, FiscalItemDto>
        {
            private readonly FiscalItemService _service;

            public AddFiscalItemCommandHandler(FiscalItemService service)
            {
                _service = service;
            }

            public async Task<FiscalItemDto> Handle(AddFiscalItemCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperFiscalItem.MapToFiscalItemDto(newEntity);
            }
        }

        public class AddFiscalItemCommandValidator : AbstractValidator<AddFiscalItemCommand>
        {
            public AddFiscalItemCommandValidator()
            {
                RuleFor(c => c.Request.PLU).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
                RuleFor(c => c.Request.VAT).NotEmpty();
            }
        }
    }
}