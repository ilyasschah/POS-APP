using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.FiscalItemCommands.Update
{
    public class UpdateFiscalItemCommand : IRequest<bool>
    {
        public int PLU { get; }
        public UpdateFiscalItemRequest Request { get; }

        public UpdateFiscalItemCommand(int plu, UpdateFiscalItemRequest request)
        {
            PLU = plu;
            Request = request;
        }

        public class UpdateFiscalItemCommandHandler : IRequestHandler<UpdateFiscalItemCommand, bool>
        {
            private readonly FiscalItemService _service;

            public UpdateFiscalItemCommandHandler(FiscalItemService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateFiscalItemCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.PLU, command.Request);
            }
        }

        public class UpdateFiscalItemCommandValidator : AbstractValidator<UpdateFiscalItemCommand>
        {
            public UpdateFiscalItemCommandValidator()
            {
                RuleFor(c => c.PLU).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
                RuleFor(c => c.Request.VAT).NotEmpty();
            }
        }
    }
}