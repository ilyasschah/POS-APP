using MediatR;
using FluentValidation;
using Api.Services;

namespace Api.Commands.PosOrderCommand
{
    public class DeletePosOrderCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public DeletePosOrderCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeletePosOrderCommandValidator : AbstractValidator<DeletePosOrderCommand>
        {
            public DeletePosOrderCommandValidator()
            {
                RuleFor(x => x.Id)
                    .GreaterThan(0).WithMessage("Order ID must be valid.");

                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }

        public class DeletePosOrderCommandHandler : IRequestHandler<DeletePosOrderCommand, bool>
        {
            private readonly PosOrderService _service;

            public DeletePosOrderCommandHandler(PosOrderService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeletePosOrderCommand command, CancellationToken cancellationToken)
            {
                return await _service.Delete(command.Id, command.CompanyId);
            }
        }
    }
}